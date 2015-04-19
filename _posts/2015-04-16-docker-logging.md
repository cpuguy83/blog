---
layout: post
title: 'Docker logging'
date: 2015-04-16 20:00
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

Logging in Docker has always been quite convenient for a developer. Send your
logs to stdout/stderr and Docker picks them up, you can view them with
`docker logs`. This command lets you tail the logs, follow them, etc. It can be
really nice. 
In production scenarios this has proven to be a pain point...

<!--break-->

As it turns out, in production, people like to actually collect logs from multiple
servers, do analytics, and other fun things. Unfortunately docker's logging
didn't really handle this well. There are some projects that help you extract
container logs out of Docker directly and forward them to another service
(e.g. [Logspout](https://github.com/progrium/logspout)), however this is less
than ideal.

Docker 1.6 changes this. The logging infrastructure in Docker has been
driver-ized. A default logging driver can be selected when setting up the
daemon, this can get overridden when creating containers. 
Included drivers are: 

- json-log
- none
- syslog

The `json-log` driver mimics the logging of previous versions of Docker. 

The `none` driver disables logging, especially useful for those really noisy
apps. 

The `syslog` driver... well... logs to syslog. 
Here's an example output from a container using the syslog driver, with the an
entry from nginx:

```
docker/cc198c45b027[16853]: 172.17.0.7 - - [17/Apr/2015:02:00:02 +0000] "GET / HTTP/1.1" 200 2461 "-" "Mozilla/5.0 (Windows NT 5.1; rv:6.0.2) Gecko/20100101 Firefox/6.0.2"
```

The tag being used here is `docker/<container id>[pid]`. There's been some
discussion on using the container's name here instead of the ID... ultimately
in the future this will likely be configurable to use whatever container field
you want. The `pid` in this case is the actual pid as it is seen from the host,
not the pid from inside the container.


The `docker logs` command will only work with the `json-file` driver, but I'm
sure you probably already have your own tool for reading logs that's way better
than what `docker logs` could provide.

It should also be extremely simple to write a custom logging driver, the `syslog`
driver is a grand total of 45 lines of code
([syslog.go](https://github.com/docker/docker/blob/v1.6.0/daemon/logger/syslog/syslog.go)).
Here are the interfaces:

```go
type Message struct {
	ContainerID string
	Line        []byte
	Source      string
	Timestamp   time.Time
}

type Logger interface {
	Log(*Message) error
	Name() string
	Close() error
}
```

So if none of the currently available logging drivers suits you, it should be
pretty simple to implement your own!

And as always, pull requests are _always_ welcome!
