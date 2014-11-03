---
layout: post
title: 'Docker In-depth: Volumes'
date: 2014-11-03 11:00
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

One of the most common roadblocks for people using Docker, and indeed easily the
most common questions I see on on various Docker support channels, is regarding
the use of volumes.

So let's take a closer look at how volumes work in Docker.

<!--break-->

First, let's dispell the most common and first misconception:

  Docker volumes are for persistsence.

This likely comes from the idea that container's are not persitant, which is
indeed not true.  Container's persist until you remove them, and you can only do
that by doing

```bash
docker rm my_container
```

If you did not type this command then your container still exists and will
continue to exist, can be started, stopped, etc.  If you do not see your
container, you should see this:

```
docker ps -a
```

`docker ps` only ever shows you running containers, but a container can be in a
stopped state, in which case the above command would show you all containers
regardless of state.  `docker run ...` is actually a multi-part command, it
creates a _new_ container, then starts it.

So, again, volumes are _not_ for persitance.

### What is a volume

Volumes decouple the life of the data being stored in them from the life of the
container that created them.  This makes it so you _can_
`docker rm my_container` and your data will not be removed.

A volume can be created in two ways:

  1. Specifying `VOLUME /some/dir` in a Dockerfile
  2. Specying it as part of your run command as `docker run -v /some/dir`

Either way, these two things do _exactly_ the same thing. It tells Docker to
create a directory on the host, within the docker root path
(by default /var/lib/docker), and mount it to the path you've specified
(`/some/dir` above).  When you remove the container using this volume, the
volume itself continues to live on.

If the path specified does not exist within the container, a directory will be
automatically created.

You can tell docker to remove a volume along with the container:

```bash
docker rm -v my_container
```

Sometimes you've already got a directory on your host that you want to use in
the container, so the CLI has an extra option for specifying this:

```bash
docker run -v /host/path:/some/path ...
```

This tells docker to use the specified host path specifically, instead of
creating one itself within the docker root, and mount that to the specified path
within the container (`/some/path` above). Note, that this can also be a file
instead of a directory. This is commonly referred to as a bind-mount within
docker terminology (though technically speaking, all volumes are bind-mounts in
the sense of what is actually happening).
If the path on the host does not exist, a directory will be automatically be
created at the given path.

Bind-mount volumes are treated a little differently than a "normal" volume, with
the preference of not modfying things on the host that Docker did not itself
create:

  1. With a "normal" volume, docker will automatically copy data at the
  specified volume path (e.g. `/some/path`, above) into the new directory that
  was created by docker, with a "bind-mount" volume this does not happen.
  2. When you `docker rm -v my_container` a container with "bind-mount" volumes,
  the "bind-mount" volumes will _not_ be removed.


You can share volumes with another container.

```bash
docker run --name my_container -v /some/path ...
docker run --volumes-from my_container --name my_container2 ...
```

The command above will tell docker to mount the same volumes from the first
container into the 2nd container.  This effectively allows you to share data
between two containers.

If you `docker rm -v my_container`, if the 2nd container above still exists, the
volumes will _not_ be removed, and indeed will not ever be removed unless you
remove the second container with the same `docker rm -v my_container2`.

### VOLUME in Dockerfiles

As mentioned earlier, the `VOLUME` declaration in a `Dockerfile` does the same
exact thing as the `-v` flag on the `docker run` command (except you can't
specify a host path in a `Dockerfile`).  It just so happens that because of
this, there can be suprising effects when building your image.

Each command in a `Dockerfile` creates a new container which runs the specified
command and commits the container back to an image, each step building off the
previous one.  So `ENV FOO=bar` in a dockerfile is the equivelant of:

```bash
cid=$(docker run -e FOO=bar <image>)
docker commit $cid
```

So let's look at what happens with  this example `Dockerfile`

```Dockerfile
FROM debian:jessie
VOLUME /foo/bar
RUN touch /foo/bar/baz
```
```bash
docker build -t my_debian .
```

What we expect to happen here is docker to create an image called `my_debian`
with a volume at `/foo/bar` and put an empty file at `/foo/bar/baz`, but let's
look at the equivelant CLI commands actually do:

```bash
cid=$(docker run -v /foo/bar debian:jessie)
image_id=$(docker commit $cid)
cid=$(docker run $image_id touch /foo/bar/baz)
docker commit $(cid) my_debian
```

Now, this isn't _exactly_ what happens, but it is a very close approximation.

So, what happened here is the volume is created before anything is actually in
`/foo/bar`, and as such every time we start a container from this image we will
have an _emtpy_ directory at `/foo/bar`.  This happens because as stated earlier,
each `Dockerfile` command is creating a new container.  This means a _new volume_
is also created.  Since in the example `Dockerfile` the volume is specified
before anything existed in that directory, when the container that was created
to run the `touch /foo/bar/baz` command, it did so with a volume mounted in for
`/foo/bar`, so `baz` was written to the volume mounted at `/foo/bar`, not the
actual container/image filesystem.

So, keep in mind the placement of your `VOLUME` declarations in your Dockerfile
as it does create essentially immutable directories in your image.

~~`docker cp`~~([#8509](https://github.com/docker/docker/pull/8509)),
`docker commit`, and `docker export` do not support volumes (yet).

Currently, the only way to manage volumes (create/destroy) is during container
creation/descruction, which is a little odd since volumes are meant to
decouple the data contained within them from the life of the container. This is
something being worked on but is not yet merged
([#8484](https://github.com/docker/docker/pull/8484)).

If you want this sort of functionality, checkout
[docker-volumes](https://github.com/cpuguy83/docker-volumes)
