---
layout: post
title: 'Docker Quicktip #1: Entrypoint'
date: 2014-01-27 02:51:50.000000000 +00:00
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '2179765266'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

The first tip is aptly named "Entrypoint". In this tips I kind of expect that you've played around with Docker a bit, probably even have some containers running for your dev environment.  So, in short, if you haven't played yet, go play and come back!

<!--break-->

Entrypoint is great.  It's pretty much like `CMD` but essentially let's you use re-purpose `CMD` as runtime arguments to `ENTRYPOINT`. For example...

Instead of:

`docker run -i -t -rm busybox /bin/echo foo`

You can do:

`docker run -i -t -rm -entrypoint /bin/echo busybox foo`

This sets the entrypoint, or the command that is executed when the container starts, to call /bin/echo, and then passes "foo" as an argument to /bin/echo.

Or you can do, in a Dockerfile:

```Dockerfile
FROM busybox

ENTRYPOINT ["/bin/echo", "foo"]
```

```bash
docker build -rm -t me/echo .
docker run -i -t -rm me/echo bar
```

This passes bar as an additional argument into /bin/echo foo, resulting in `/bin/echo foo bar`

Why would you want this?  You can think of it as turning `CMD` into a set of optional arguments for running the container.  You can use it to make the container much more versatile. This will lead into the next tip "Exec it"
