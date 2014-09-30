---
layout: post
title: 'Docker Quicktip #6: Restart Policies'
date: 2014-09-30 11:00
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

Docker 1.2 introduced a powerful new feature called "restart policies".
Restart policies replaces the old daemon "-r" option, which itself would try to
restart all previously running containers upon daemon restart, however this was
rife with trouble.

<!--break-->

  1. It just flat out didn't always work, and was basically unreliable in
  production
  2. Maybe you didn't actually need _all_ of your containers restarted
  3. It did not resolve links, so if a container had links and docker tried to
  start that container before the linked container was started, it would fail
  to start.
  4. Does not apply to container crashes/stopping

With restart policies this all changes.

  1. When your system boots and starts up docker, docker will reliabily restart
  all containers that have a restart policy applied
  2. You can specify per-container what the restart polciy should be
  3. Docker will walk link dependencies and start them in the correct order
  4. Will monitor/restart crashed containers


### Usage

```bash
docker run -d --restart always --name myredis redis
docker run -d --restart always --link myredis:redisdb myapp
```

Other restart policy modes are:

  * no - no restart policy
  * on-failure - restart if exit code is not 0

Docker will also back-off on restarts if they are too frequent, and when using
"on-failure" you can set the max restarts.


On minimal distros such as boot2docker, restart policies can be used in place of
an init system... I'd even argue that if you are containerizing everything it
should always replace an init system.

Basically, if you aren't using resart policies you are doing it wrong. If you
aren't using restart=always on your long running processes you are probably also
doing it wrong.
