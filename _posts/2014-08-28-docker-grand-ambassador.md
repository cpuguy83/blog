---
layout: post
title: Docker Grand Ambassador
date: 2014-08-28 15:15:00
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

In Docker, when you want two containers to be able to discover each other and
communicate, you use links... Or at least when you first started you did and
and then you gave up because links don't work well right now.

The problem with linking is that links are static. When a container which is
being linked to is restarted it very likely has a new IP address. Any container
which is linked to this restarted container will also need to be restarted in
order to pick up this new IP address. Therefore linked containers can often have
a cascading effect of needing to restart many containers in order to update
links.

<!--break-->

Links can also only be created one-way, and the linked-to container must exist,
and be running, in order to link to it.

You can use the [Ambassador pattern](http://docs.docker.com/articles/ambassador_pattern_linking/)
as a way to mitigate this, but as used in the example they it is marginally
useful in a multi-host setup and much less useful in a single host scenario.

Indeed solutions to this are being worked on:

* [Proposal: Links: Dynamic Links](https://github.com/docker/docker/issues/7468)
* [Proposal: Links: Upgrading the network model](https://github.com/docker/docker/issues/7467)
* [Update /etc/hosts when linked container is restarted](https://github.com/docker/docker/pull/7677) -> This one just got merged!

People do however need something for now.  SkyDNS+SkyDock, etcd, consul, etc all
exist for this.
I've personally used and recommended SkyDNS+Skydock, however running a DNS server
isn't neccessarily desirable.  For the others, your applications need to be
modified to take advantage of them.

This is why I created [Grand Ambassador](https://github.com/cpuguy83/docker-grand-ambassador).
Grand Ambassador acts as a proxy server for accessing some container, much like
the example in the *Ambassador Pattern Linking* article linked to above. What
Grand Ambassador does differently is that it is dynamic. That means it will not
only automatically create a proxy on all exposed ports for the passed in
container, it will also automatically detect changes to that container and adjust
the proxy server accordingly (e.g. it has a new IP address b/c of a container restart)

### Example Usage:
```bash
docker run -d --expose 6379 --name redis redis
docker run -d -v /var/run/docker.sock:/var/run/docker.sock \
  --name red-amb \
  cpuguy83/docker-grand-ambassador -name redis
docker run --rm --link red-amb:db redis redis-cli -h db ping
```

In the above example, the redis-ambassador is used in place of the actual redis
container for connecting to it.  I can restart the redis container and the
ambassador will detect that change and adjust accordingly.  No need to restart
the ambassador or the linking container as you would without the ambassador.


So this has actually been out for a little while now, I just never posted about
it. Recently I made some updates to it that enables some interesting
functionality.

```bash
docker run -d -v /var/run/docker.sock:/var/run/docker.sock \
  --name red-amb cpuguy83/docker-grand-ambassador -name redis
docker run -d --expose 6379 --name redis redis
docker run --link redis-amb:db redis redis-cli -h db ping
```

Here you can see I am creating the ambassador *before* the redis container even
exists.  The ambassador will wait for the container with the given name to be
created and then automatically setup the proxy for our redis-cli to use

I can also:

```bash
# continued from above
docker rm -f redis
docker run -d --name --expose 6379 redis redis
docker run --link redis-amb:db redis redis-cli -h db ping
```

Here, with everything still running, I can remove the redis container and create
a new one with the same name.  Grand Ambassador will see the removal, stop the
proxy, then wait for the container with the same name to be created/started
again. So, for instnace, you can create a make a quick configuration change to
redis, create a new container, and all without modifying, restarting, change in
any way the container that is actually wanting to use redis.

*The above examples are rudimentary for demo purposes.  You could have a
full-blown app which does not exit like the `redis-cli -h db ping` does.*
