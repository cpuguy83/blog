---
layout: post
title: Persistent volumes with Docker - Data-only container pattern
date: 2013-12-16 16:32:42.000000000 +00:00
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '2054307876'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

Docker has an option to allow specific folders in a container to be mapped to
the normal filesystem on the host.  This allows us to have data in the container
without making the data part of the Docker image, and without being bound to
AUFS.

There are a couple of issues with using volumes in certain scenarios:

<!--break-->

1.  Volumes are container specific, when you create a new container, even with
the same image, you do not have access to the data.
2.  Since image layers are built using containers, data saved to folders which
have been specified as a volume does not make it to the next layer, or your
final container

If you want data to persist between updated containers you have to manually map
data to the host outside the normal, container-specific mount points.

For example, when creating a container:

```bash
docker run -d -v /var/container_data/mysql:/var/lib/mysql me/awesome_mysql_image
```

This, however, is generally not a good idea as you are tying the container to
that host and you lose one of the things that makes Docker great: portability.

In addition to this, you've now created a container storage location that is
not under Docker's control.

But... data must be able to be persisted, especially in the use case above, so
new versions of an image can be used to replace the current container... so we
take the risk and do it anyway.

**Introducing: Data-only containers**

Volumes are still great!  We can still use them and use them as intended by our
Docker overlords!

Instead of manually setting these mount points on the docker host, let's take
the concept of SRP (Single Responsibility Principle) a bit farther.

We can create a container which is solely for storing data for another
container:

Create the data-only container:

```
# docker run -d -v /var/lib/mysql -name data-mysql --enterypoint /bin/echo mysql
data-only container for mysql
```

Great, so now we have a container which has a volume for /var/lib/mysql... now
what.

Docker allows us to pull in volumes from another container to use in our own...
using the above mysql example this would look like:

```
docker run -d -volumes-from data-mysql -e MYSQL_ROOT_PASS="muchsecurity" mysql
```

Here, all data being saved by mysql will be stored in the volume specified by
the `data-mysql` container.

Since the `data-mysql` container likely won't ever need to be updated, and if it
does we can easily handle moving the data around as needed, we essentially
work-around the issues listed above and we still have good portability.

We can now create as many mysql instances as we can handle and use volumes from
as many `data-mysql` style containers as we want as well (provided unique naming
or use of container ID's).  This can much more easily be scripted than mounting
folders ourselves since we are letting docker do the heavy lifting.

One thing that's really cool is that these data-only containers don't even nee
to be running, it just needs to exist.

This pattern definitely does not fit all use cases, but it may fit yours!
Try it out!
