---
layout: post
title: 'containerd Deep Dive: Intro to containerd'
date: 2017-10-14 16:00
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

You may have heard a lot about containerd recently, but did you know you've
probably been using it for over a year?

This series will take a deep dive into what's new with containerd, its origins,
any why you should care.

<!--break-->

### Origins

containerd began its life as a component of Docker 1.11 when it replaced
Docker Engine's built-in container execution model as an external component.
With containerd, Docker Engine gained support for the early draft OCI specs
which means it became relatively trivial to add support for new execution
environments without having to change the main Docker codebase. containerd was
built to execute containers efficiently with whatever OCI compatible runtime
the user wanted to use. The introduction of containerd also came with being
able to
[delete a large swath](https://github.com/moby/moby/pull/20662/commits/6eebe85290327ee9934ea996b6ef82c579789d97)
of complicated, platform dependent code from dockerd.

So this thing has been around for awhile, why should you care? With the Docker
Engine moving further up the stack with things like multi-host networking,
service discovery, and swarm-mode orchestration it became clear that both within
Docker and in the greater community that there was a need for something more than
what containerd offered and yet much less than what Docker engine provides, and
with fewer opinions.
There is a lot more effort in managing containers than just the execution of them,
including distribution, storage, networking, and other tasks. After much time
was spent thinking and discussing with the community what was really needed, the
containerd 1.0 project was kicked off.

### containerd 1.0

So what is containerd 1.0 all about? In short, it's a new container runtime
built with no baggage, four years worth of hindsight, and a well defined scope.
It's designed to be wrapped, easily integrated with, and customizable meanwhile
providing the right functionality so that consumers of containerd don't have to
re-implement a lot of the same functionality. It provides a base set of (GRPC)
services backed by implementations which are fully pluggable, either via
compiled in plugins or using go 1.8's dynamic plugin model (nothing to do with
Docker style plugins).
None of the containerd services are strongly coupled, so you can choose to use
one piece and not another, and combine them in whatever way that your integration
demands.

One thing you might ask is why "1.0"? The most recent release of containerd, and
the one that's currently shipping with Docker (as of Docker CE 17.09), is from
the v0.2.x tree of containerd. It's not "v0.2" because the software itself is
unstable, but because the API's are not stabilized, and even the spec it depends
on (OCI runtime spec) was only recently brought to 1.0. Docker deals with any
API breakages in containerd internally and the user is not concerned with it.

Along with the "1.0" version, the containerd project is also defining a sensible
[support timeline](https://github.com/containerd/containerd/blob/master/RELEASES.md#support-horizon)
for releases.
Docker has also
[donated containerd to the CNCF](https://www.cncf.io/announcement/2017/03/29/containerd-joins-cloud-native-computing-foundation/).

So what do these services look like? Here's a high-level view, we'll go deeper
into each service in subsequent posts in this series.  
*note*: much of this can be found in the
[design doc](https://github.com/containerd/containerd/blob/master/design/architecture.md)

#### Content

The content service is a content addressable storage system. When the client pulls
an image, the image gets stored into the content store. Docker also has a
content-addressable store, but Docker does not expose it to clients and is only
used for images.

All immutable content gets stored in the content store. This doesn't have to be
container images, and in fact the store doesn't care what the type is.

#### Snapshot

The snapshot service manages filesystem snapshots for container images. This is
similar (in concept only) to the graphdriver in Docker (e.g. overlay, btrfs,
devicemapper, etc).  One big difference is the client interacts directly with
snapshot service whereas in Docker clients only interact with the image itself
and has no control in where or how an image is unpacked.

Another major, and quite novel I think, difference with Docker's graphdrivers
is a snapshot driver does not manage the actual mounts but rather returns a
list of mounts that the client needs to perform in order to operate. You'll
find that the inputs of other services dealing with the filesystem is a list of
mounts rather than a path on disk that is already expected to be mounted.

The overall design of snapshots is very different from Docker, I encourage you
to check it out if you are interested in this sort of thing.

#### Diff

The diff service generates and applies diffs between filesystem mounts.

#### Images

The image service provides access to the images stored in containerd. An image
is really just metadata with references to the content stored in the content
store.

#### Containers

The container service provides access to the containers in containerd. Unlike
Docker, a container is just a metadata object. If you create a container, you
are only creating metadata. A `Container` is a parent of a `Task`

#### Tasks

The task service allows a client to manage a container's runtime state. When
you create a container you are creating metadata, when you create a task you
are allocating runtime resources. Tasks can be started and stopped, paused and
resumed, etc. If you want container metrics, this is where you get them.

#### Events

The events service is a pub/sub service used by clients and other services in
order notify of specific things occuring within a service. A client can use
events to find out things like when a container was started and stopped among
other things.

#### Introspection

The introspection service provides details about the running containerd instance.
A client can, for example, use this to find out about loaded plugins, their
capabilities, etc.

----

containerd 1.0 makes use of a rich-client model where containerd itself doesn't
impose many opinions but rather the functionality for the client to make its
own opinion. This comes at a trade-off of putting more work on client builders
to implement their own features.

Just as an example of what "rich-client" means, here is an example of how an
image would get created in containerd from a registry. Take note that the pull
operation (and push for that matter) is all client side and uses containerd
services to store the content and unpack onto a filesystem.

[![containerd-dataflow-pull](/assets/containerd-dataflow-pull.png)](/assets/containerd-dataflow-pull.png)

*graphics courtesy of [Stephen Day](https://github.com/stevvooe)*


While containerd does use GRPC as an API, and thus anyone can generate their
own client, it also provides an unopinionated, rich Go client implementation
which does not require dealing with the GRPC layer itself.

Here is a code-snippet using the provided go client to run a redis container:

*note:* This example is intentionally using mostly defaults and letting the client
make a lot of choices for us, in a follow-up we'll go through just how much you
can do.

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

Work is [on-going](https://github.com/moby/moby/pull/34895) to move Docker to
containerd 1.0, likely with a slow move to have Docker use more and more of
containerd's services.
You can also try out containerd with Kubernetes with
[cri-containerd](https://github.com/kubernetes-incubator/cri-containerd/releases).
If you've tried out [linuxkit](https://github.com/linuxkit/linuxkit) you've
already used the new containerd!

*Note*: containerd 1.0 is currently in the beta stage, check out the
[releases](https://github.com/containerd/containerd/releases) page to track its
progress.

There's much more detail to go into here, so look forward to more posts about
containerd.
