---
layout: post
title: libswarm demotime - logging
date: 2014-07-17 20:09:12.000000000 +00:00
categories: []
tags:
- Docker
- libswarm
- Orchestration
status: publish
type: post
published: true
meta:
  dsq_thread_id: '2851974797'
  _edit_last: '1'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

If you don't know what libswarm is take a gander at [Libswarm in a nutshell](http://www.tech-d.net/2014/07/03/libswarm/ "Libswarm (in a nutshell)")

Just a quick demo showing off what libswarm can do with logging.

I will be using code from this gist: [https://gist.github.com/cpuguy83/b7c0f42e903bc13c46d6](https://gist.github.com/cpuguy83/b7c0f42e903bc13c46d6)

Demo time!

<!--break-->


```bash
# start a container that prints to stdout
docker -H tcp://10.0.0.2:2375 run -d --entrypoint /bin/sh debian:jessie -c \
    'while true; do echo this is a log message; sleep 1; done'

# fire up swarmd
./swarmd 'logforwarder tcp://10.0.0.2:2375' stdoutlogger
Getting logs tcp://10.0.0.2:2375 [agitated_yonath]
2014-07-17 19:04:22.42915222 +0000 UTC	tcp://10.0.0.2:2375	agitated_yonath	INFO	this is a log message

2014-07-17 19:04:23.43114032 +0000 UTC	tcp://10.0.0.2:2375	agitated_yonath	INFO	this is a log message
```

[![libswarm-logforwarder-1daemon](/assets/libswarm-logforwarder-1daemon.png)](http://www.tech-d.net/wp-content/uploads/2014/07/libswarm-logforwarder-1daemon.png)

So we told swarmd to fire up the logforwarder backend and connect to the docker daemon on tcp://10.0.0.2:2375, attach to each of the containers in the daemon, convert the stdout/stderr streams to log messages and forward them into the stdoutlogger (which is a backend made simply for demo purposes) which prints to the terminal's stdout.

```
# Now lets connect to multiple daemons with multiple containers
docker -H tcp://10.0.0.2:2375 run -d --entrypoint /bin/sh debian:jessie -c \
    'while true; do echo this is a log message; sleep 1; done'
docker -H tcp://10.0.0.2:2375 run -d --entrypoint /bin/sh debian:jessie -c \
    'while true; do echo this is a log message; sleep 1; done'

docker -H tcp://10.0.0.3:2375 run -d --entrypoint /bin/sh debian:jessie -c \
    'while true; do echo this is also a log message; sleep 1; done'

./swarmd 'logforwarder tcp://10.0.0.2:2375 tcp://10.0.0.3:2375' stdoutlogger
Getting logs tcp://10.0.0.2:2375 [agitated_yonath romantic_wozniak]
Getting logs tcp://10.0.0.3:2375 [hopeful_babbage]
2014-07-17 19:40:22.93898444 +0000 UTC	tcp://10.0.0.2:2375	agitated_yonath	INFO	this is a log message

2014-07-17 19:40:23.26841138 +0000 UTC	tcp://10.0.0.3:2375	hopeful_babbage	INFO	this is also a log message

2014-07-17 19:40:23.63765218 +0000 UTC	tcp://10.0.0.2:2375	romantic_wozniak	INFO	this too is a log message

2014-07-17 19:40:23.94244022 +0000 UTC	tcp://10.0.0.2:2375	agitated_yonath	INFO	this is a log message

2014-07-17 19:40:24.27086067 +0000 UTC	tcp://10.0.0.3:2375	hopeful_babbage	INFO	this is also a log message

2014-07-17 19:40:24.64303259 +0000 UTC	tcp://10.0.0.2:2375	romantic_wozniak	INFO	this too is a log message
```

Here we have the logforwarder connecting to 2 docker backends, attaching to each of the containers and forwarding the stdout/stderr streams to the `stdoutlogger`.

[![libswarm-logforwarder-2daemons](/assets/libswarm-logforwarder-2daemons.png)](http://www.tech-d.net/wp-content/uploads/2014/07/libswarm-logforwarder-2daemons.png)

Instead of `stdoutlogger`, this could be swapped out for syslog, logstash, whatever... it just needs to implement the libswarm `Log` verb.

[![libswarm-logforwarder-syslog](/assets/libswarm-logforwarder-syslog.png)](http://www.tech-d.net/wp-content/uploads/2014/07/libswarm-logforwarder-syslog.png)
