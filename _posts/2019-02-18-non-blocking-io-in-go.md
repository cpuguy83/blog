---
layout: post
title: 'Non-blocking I/O in Go'
date: 2019-02-18 16:00
tags:
- Docker
- Containers
- containerd
status: publish
type: post
published: true
author:
  email: cpuguy83@gmail.com
  first_name: Brian
  last_name: Goff
---

Whether you know it or not, if you are using Go you are probably using
non-blocking I/O. This post will dig in a little into that, but go further into
how you can actually take more control of the I/O handling in Go. This is
especially nice as go1.11 and go1.12 add some very interesting interfaces to
help with this.  This had a slightly different conclusion than I’d expected,
but 🤷‍♂, stuff happens

<!--break-->

What is non-blocking I/O? A simple explanation: It allows you to `read()` and
`write()` to a file descriptor (that is, any type of open file be it a socket,
pipe, a file on disk, whatever) without having these calls block just because
the file is not ready. How does this work? A little something like this:

```go
fd, _ := syscall.Open("/foo", syscall.O_CREAT|syscall.O_RDWR|syscall.O_CLOEXEC|syscall.O_NONBLOCK, 0644)
```

This is instructing the system to:

1. open the file at /foo, create it if it does not exist (`O_CREAT`)

1. close the file if executing a new processes (`O_CLOEXEC`)… this is important to not copy file descriptors between processes unexpectedly

1. Open the file with both read and write access

1. Use non-blocking mode (`O_NONBLOCK`)

1. Set the permissions on new files

That’s cool, but what does it actually mean? Well, for a regular file not much
because they are always readable and always writable…. but… other types of
files, such as a pipe this gets very interesting, so instead we can do this
before we open the file:

```go
syscall.Mkfifo("/foo", 0644)
```

This will create a fix-sized pipe buffer. Without the `O_NONBLOCK` flag, when a
`read()` is performed, the caller will block until there is data to read.
Likewise when a write() is performed the caller will be blocked if the pipe is
full. Here we are using `O_NONBLOCK`, and so will have slightly different
semantics. Instead of blocking, a call to `read()` on an empty pipe or `write()` to
a full pipe will return an `EAGAIN` error. This is a nice way of saying the pipe
is not ready for that action (the error message might like resource temporarily
unavailable). `EAGAIN` really means “try again”, there is an alias for this error
called `EWOULDBLOCK`.

From here you might want to use a polling mechanism such as epoll to be
notified of when the pipe is ready for read or write (depending on what you
need).

So, Go does all this for you. When you call os.Open(...), Go opens the file
with the non-blocking flag, sets up watches for the file descriptor to know
when it’s ready for read/write/is closed, and then provides a blocking API on
top of non-blocking I/O for a natural flow like so:

```go
buf := make([]byte, 32)
n, _ := f.Read(buf)
fmt.Println(string(buf[:n]))
```

So, the `fmt.Println` doesn’t happen until Read has completed. If the file is not
ready for `read()`, it pauses the goroutinue and allows other goroutines to run
while it waits for it to be ready, then wakes up our goroutine when it is ready
so it can continue. This is really nice and simple, don’t have to think about
callbacks, or polling API’s, or any low-level details and get all the benefit
of asynchronous I/O.

The trouble is, a blocking API isn’t always what you want. Sometimes you
actually need lower-level control than what you might see in a typical Go
program. A relatively simple example of this is this:

```go
buf := make([]byte, 32)
go func() { f2.Close() }
for {
    n, err := f1.Read(buf)
    if err != nil {
        break
    }
    f2.Write(buf[:n])
}
```

This looks harmless, but what if `f1` just blocks because there is never any data
(or is just not closed… for good reason), the goroutine running this will run
forever, blocking on the call to Read … this happens even if `f2` is closed.

*note: this may actually be more pervasive in the go ecosystem than is
realized, especially a problem in Docker’s code base… the above code is
essentially what io.Copy does.*

Other cases where one might need this level of control is implementing
semantics for custom read/write behavior, perhaps those using zero-copy
techniques such as `splice()`.

So, what’s the alternative? Bypass the go runtime and do our own file polling
and switching? Oh no. This would be horribly annoying. Before `go1.11`, though,
this would be precisely what one needed to do, except for some few cases where
you can get access to the underlying file descriptor.

Starting with `go1.11`, there are two new interfaces:

- [syscall.Conn](https://golang.org/pkg/syscall/#Conn)
- [syscall.RawConn](https://golang.org/pkg/syscall/#RawConn)

These interfaces essentially allow Go to expose the raw file descriptor but
without sacrificing any control by the runtime itself to do weird things (such
as swap out file descriptors from beneath you) AND allows the caller to still
utilize the built-in runtime poller so you don’t have to deal with these
semantics yourself.  The Read and Write methods on this interface take a
function which gets called in a loop when the file descriptor is ready for the
operation, and it’s up to you to determine when to hand off back to Go,
normally you’d do this when you receive `EAGAIN`.

This was utilized in `go1.11` to support transparently copying (even via `io.Copy`)
between two TCP connections using zero-copy techniques (`splice()` on linux).

*note: this is implemented in the
[ReadFrom](https://golang.org/pkg/net/#TCPConn.ReadFrom) method*

I recently added support for syscall.Conn to [containerd’s fifo
package](https://github.com/containerd/fifo/pull/17) (`go1.12` only), which is
used for buffering stdio from containers. I’ve also been [working on a similar
ReadFrom
implementation](https://github.com/containerd/fifo/compare/master...cpuguy83:add_raw_copy?expand=1)
as above for this package to get the same sort of zero-copy behavior, [which
shows extremely promising
results](https://gist.github.com/cpuguy83/530e8a40eb03dc08c4072686cfaff053)
when copying between two pipes (very common in container-land)… however I’m
still trying to decide if this complexity is worth it in the library vs just
having some supporting library deal with this… where we’d want to use `tee()` in
addition to `splice()` to copy I/O to multiple destinations anyway. The benefit
here is getting zero-copy performance without setting up my own poller.

So… back to the problem stated above… what does this look like with our above
example? Honestly still not all that simple because we’d need to setup our own
epoll on f2 to know when the file has been closed and then go ahead and cleanup
`f1`.

To do that we’d use `syscall.RawConn`'s `Control(func(uintptr))` definition to
get access to the file descriptor.  This is because there is no means of
getting a close notification from the runtime poller… writing this I think I
may just open a feature request 😃, but at least it is sort of possible without
such a feature.
