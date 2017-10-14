---
layout: post
title: 'containerD Deep Dive: Intro to ContainerD'
date: 2017-10-14 16:00
tags:
- Docker
- Containers
status: publish
type: post
published: false
author:
  email: cpuguy83@gmail.com
  first_name: Brian
  last_name: Goff
---

You may have heard a lot about containerD recently, but did you know you've
probably been using it for over a year?

This series will take a deep dive into what's new with ContainerD, its origins,
any why you should care.

<!--break-->

### Origins

containerD began its life as a component of Docker 1.11 when it replaced
Docker Engine's built-in container execution model as an external component.
With containerD, Docker Engine gained support for the early draft OCI specs
which means it became relatively trivial to add support for new execution
environments without having to change the main Docker codebase. containerD was
built to execute containers efficiently with whatever OCI compatible runtime
the user wanted to use. The introduction of containerD also came with being
able to
[delete a large swath](https://github.com/moby/moby/pull/20662/commits/6eebe85290327ee9934ea996b6ef82c579789d97)
of complicated, platform dependent code from dockerd.

So this thing has been around for awhile, why should you care? With the Docker
Engine moving further up the stack with things like multi-host networking,
service discovery, and swarm-mode orchestration it became clear that both within
Docker and in the greater community that there was a need for somethign more than
what containerD offered and yet much less than what Docker engine offered and
with fewer opinions.
There is a lot more effort in managing containers than just the execution of them,
including distribution, storage, networking, and other tasks. After much time
was spent thinking and discussing with the community what was really needed, the
containerD 1.0 project was kicked off.

### containerD 1.0

So what is containerD 1.0 all about? In short, it's a new container runtime built
with no baggage, four years worth of hindsight, and a well defined scope.
It's designed to be wrapped, easily integrated with, and customizabe meanwhile
providing the right functionality so that consumers of containerD don't have to
re-implement a lot of the same functionality. It provides a base set of (GRPC)
services backed by implementations which are fully pluggable, either via
compiled in plugins or using go 1.8's dynamic plugin model (nothing to do with Docker style plugins).

The containerD project is also defining a sensible
[support timeline](https://github.com/containerd/containerd/blob/master/RELEASES.md#support-horizon)
for releases.
Along with this, Docker has
[donated containerD to the CNCF](https://www.cncf.io/announcement/2017/03/29/containerd-joins-cloud-native-computing-foundation/).

So what do these services look like? Here's a high-level view, we'll go deeper
into each service in subsequent posts in this series.  
*note*: much of this can be found in the
[design doc](https://github.com/containerd/containerd/blob/master/design/architecture.md)

#### Content

The content service is a content addressable storage system. When the client pulls
an image, the image gets stored into the content store. Docker also has a
content-addressable store, but this is not exposed to clients and is only used
for images.

All immutable content gets stored in the content store.

#### Snapshot

The snapshot service manages filesystem snapshots for container images. This is
similar (in concept only) to the graphdriver in Docker (e.g. overlay, btrfs, devicemapper, etc).
One big difference is the client interacts directly with snapshot service whereas
in Docker clients only interact with the image itself and has no control in where
or how an image is unpacked.

The overall design of snapshots is very different from Docker, I encourage you
to check it out if you are interested in this sort of thing.

#### Diff

The diff service generates and applies diffs between filesystem mounts.

#### Images

The image service provides access to the images stored in containerd. An image
is really just metadata with references to the content stored in the content
store.

#### Containers

The container provides access to the containers in containerd. Unlike Docker, a
container is just a metadata object. If you create a container, you are only
creating metadata. A `Container` is a parent of a `Task`

#### Tasks

The task service allows a client to manage a container's runtime state. When
you create a container you are creating metadata, when you create a task you
are allocating runtime resources. Tasks can be started and stopped.

#### Events

The events service is a pub/sub service used by clients and other services in
order notify of specific things occuring within a service. A client can use events
to find out things like when a container was started and stopped among other things

#### Introspection

The introspection service provides details about the running containerD instance.
A client can, for example, use this to find out about loaded plugins, their
capabilities, etc.

----

ContainerD 1.0 makes use of a heavy-client model where containerD itself doesn't
impose many opinions but rather the functionality for the client to make its
own opinion.

While containerD does use GRPC as an API, and thus anyone can generate their
own client, it also provides an unopinionated client implementation for Go which
does not require dealing with the GRPC layer itself.

Here is a code-snippet using the provided go client to run a redis container:

```go
	client, _ := containerd.New("/run/containerd.sock")
	ctx := namespaces.WithNamespace(context.Background(), "cpuguy") // note everything is namespaced
	image, _ := client.Pull(ctx, "docker.io/library/redis:alpine", containerd.WithPullUnpack)
	container, _ := client.NewContainer(
		ctx,
		containerd.WithNewSnapshot("my-redis", image),
		containerd.WithNewSpec(
			containerd.WithImageConfig(image),
			containerd.WithHostNamespace(specs.NetworkNamespace),
		),
	defer container.Delete(ctx, containerd.WithSnapshotCleanup)

	task, _ := container.NewTask(ctx, containerd.NewIO(os.Stdin, os.Stdout, os.Stderr))
	defer task.Delete(ctx)

	waitCh, _ := task.Wait(ctx)

	// If I wanted to do more with networking I'd do that here, before `task.Start()`

	task.Start(ctx)

	var code int
	select {
	case status := <-waitCh
		if err := status.Error(); err != nil {
			// do something if the task errored out
			fmt.Fprintln(os.Stderr, err)
			code = int(status.Code())
		}
	case <-time.After(10*time.Second)
		task.Kill(ctx, syscall.SIGKILL)
	}
	os.Exit(code)
```

There's much more detail to go into here, so look forward to more posts about
containerD.
