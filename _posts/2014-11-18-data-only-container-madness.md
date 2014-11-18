---
layout: post
title: 'Data-only container madness'
date: 2014-11-18 10:00
tags:
- Docker
- Devops
- Orchestration
status: publish
type: post
published: true
author:
  email: cpuguy83@gmail.com
  first_name: Brian
  last_name: Goff
---

Data-only containers are a pattern for managing your docker volumes with
containers instead of manually with host-mounted volumes. For more info on the
pattern, see
[Data-only container pattern](http://container42.com/2013/12/16/persistent-volumes-with-docker-container-as-volume-pattern/)

If you are using the `busybox`, `scratch`, or
`<insert minimally sized image here>`, you are doing it wrong, and here's why.

<!--break-->

Let's take this Dockerfile:

```Dockerfile
FROM debian:jessie
RUN useradd mickey
RUN mkdir /foo && touch /foo/bar && chown -R mickey:mickey /foo
USER mickey
CMD ls -lh /foo
```

Build it:

```bash
~: docker build -t mickey_foo -< Dockerfile
```

Deploy it:

```bash
~: docker run --rm -v /foo mickey_foo
total 0
-rw-r--r-- 2 mickey mickey 0 Nov 18 05:58 bar
~:
```

Ok, all good, now with a data-only container with `busybox`:

```bash
~: docker run -v /foo --name mickey_data busybox true
~: docker run --rm --volumes-from mickey_data mickey_foo
total 0
# Empty WTF??
~: docker run --rm --volumes-from mickey_data mickey_foo ls -lh /
total 68K
drwxr-xr-x   2 root root 4.0K Nov 18 06:02 bin
drwxr-xr-x   2 root root 4.0K Oct  9 18:27 boot
drwxr-xr-x   5 root root  360 Nov 18 06:05 dev
drwxr-xr-x   1 root root 4.0K Nov 18 06:05 etc
drwxr-xr-x   2 root root 4.0K Nov 18 06:02 foo
drwxr-xr-x   2 root root 4.0K Oct  9 18:27 home
drwxr-xr-x   9 root root 4.0K Nov 18 06:02 lib
drwxr-xr-x   2 root root 4.0K Nov 18 06:02 lib64
drwxr-xr-x   2 root root 4.0K Nov  5 21:40 media
drwxr-xr-x   2 root root 4.0K Oct  9 18:27 mnt
drwxr-xr-x   2 root root 4.0K Nov  5 21:40 opt
dr-xr-xr-x 120 root root    0 Nov 18 06:05 proc
drwx------   2 root root 4.0K Nov 18 06:02 root
drwxr-xr-x   3 root root 4.0K Nov 18 06:02 run
drwxr-xr-x   2 root root 4.0K Nov 18 06:02 sbin
drwxr-xr-x   2 root root 4.0K Nov  5 21:40 srv
dr-xr-xr-x  13 root root    0 Nov 18 06:05 sys
drwxrwxrwt   2 root root 4.0K Nov  5 21:46 tmp
drwxr-xr-x  10 root root 4.0K Nov 18 06:02 usr
drwxr-xr-x  11 root root 4.0K Nov 18 06:02 var
# Owened by root?  WTF???
~: docker run --rm --volumes-from mickey_data mickey_foo touch /foo/bar
touch: cannot touch '/foo/bar': Permission denied
# WTF????
```

Uh-oh, what happened? `/foo` still exists, but it's empty... and it's owned by
`root`?

Let's try this instead:

```bash
~: docker rm -v mickey_data # remove the old one
mickey_data
~: docker run --name mickey_data -v /foo mickey_foo true
~: docker run --rm --volumes-from mickey_data mickey_foo
total 0
-rw-r--r-- 1 mickey mickey 0 Nov 18 05:58 bar
# Yes!
~: docker run --rm --volumes-from mickey_data mickey_foo ls -lh /
total 68K
drwxr-xr-x   2 root   root   4.0K Nov 18 06:02 bin
drwxr-xr-x   2 root   root   4.0K Oct  9 18:27 boot
drwxr-xr-x   5 root   root    360 Nov 18 06:11 dev
drwxr-xr-x   1 root   root   4.0K Nov 18 06:11 etc
drwxr-xr-x   2 mickey mickey 4.0K Nov 18 06:10 foo
drwxr-xr-x   2 root   root   4.0K Oct  9 18:27 home
drwxr-xr-x   9 root   root   4.0K Nov 18 06:02 lib
drwxr-xr-x   2 root   root   4.0K Nov 18 06:02 lib64
drwxr-xr-x   2 root   root   4.0K Nov  5 21:40 media
drwxr-xr-x   2 root   root   4.0K Oct  9 18:27 mnt
drwxr-xr-x   2 root   root   4.0K Nov  5 21:40 opt
dr-xr-xr-x 121 root   root      0 Nov 18 06:11 proc
drwx------   2 root   root   4.0K Nov 18 06:02 root
drwxr-xr-x   3 root   root   4.0K Nov 18 06:02 run
drwxr-xr-x   2 root   root   4.0K Nov 18 06:02 sbin
drwxr-xr-x   2 root   root   4.0K Nov  5 21:40 srv
dr-xr-xr-x  13 root   root      0 Nov 18 06:05 sys
drwxrwxrwt   2 root   root   4.0K Nov  5 21:46 tmp
drwxr-xr-x  10 root   root   4.0K Nov 18 06:02 usr
drwxr-xr-x  11 root   root   4.0K Nov 18 06:02 var
# YES!!
~: docker run --rm --volumes-from mickey_data mickey_foo touch /foo/baz
~: docker run --rm --volumes-from mickey_data mickey_foo ls -lh /foo
total 0
-rw-r--r-- 1 mickey mickey 0 Nov 18 06:11 bar
-rw-r--r-- 1 mickey mickey 0 Nov 18 06:12 baz
# YES!!!
```

So what happened here?

By using the same image for both the data-container, docker was able to seed the
volume with the data from the image when we created the data container. Data
from the image is only ever seeded into a volume when the volume is created.
Since `busybox` was originally used as the image for the data-only container,
and there is no `/foo` in the `busybox` image, docker created the dir as `root`
and nothing else.  Since `--volumes-from` does not actually create a volume, it
just re-uses an existing volume, nothing ever made it into the volume itself.
Since the volume dir was owned by root and we were trying to use a non-root user
in the container to modify the volume, it failed.  
This is extremely common with images like `mongodb`, `mysql`, and `postgres`.

So are we stuck using the same image for both? Well, yes if you want it to work
as expected... however **stuck** isn't really the correct term here. The reason
we are using a minimal image is to save space, but this is not what actually
happened...

The `debian:jessie` image is roughly 150MB. Because of the way Docker works, we
can re-use the `debian:jessie` image 1000 (or 10000, or 100000) times and it is
still only ever using 150MB.  
A container itself does not take up any space unless as part of running it you've
written something to disk.  This is because a container's filesystem is
essentially a write-layer over the image. This enable Docker to use an image
**N** times (for containers) without taking up any extra space.  
So in reality, by using `busybox`, we've actually taken up **more** space than
by using the same image (ie, `mickey_foo` in the example) multiple times.

In practice, I usually do something like this:

```bash
~: docker run --name mydb-data --entrypoint /bin/echo mysql Data-only container for mydb
~: docker run -d --name mydb --volumes-from mydb-data mysql
```

In the above example, the command the data-only container ends up running is
`/bin/sh -c '/bin/echo Data-only container for mydb'`.  
This makes the data-only container relatively easy to grep for, and also gives a
good clue, based on the command being run in the container, what the container
is actually for.

