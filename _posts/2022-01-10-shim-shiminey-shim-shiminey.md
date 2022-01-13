---
layout: post
title: 'Shim-shiminey Shim-shiminey'
date: 2022-01-10 11:00
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

Today I’d like to jump in and talk about containerd’s “shim” interface. If you are interested in a more high level overview of containerd, see my [other post](https://container42.com/2017/10/14/containerd-deep-dive-intro/).

In containerd, the “shim” is responsible for all the platform specific logic for executing and interacting with a container. For every containerd or Docker container, there is a corresponding “shim” daemon process (*some exceptions apply) that serves an API which containerd uses to to interact with that container. “Interact” here means the basic lifecycle things (start/stop), execing new processes in the container, resizing tty’s and other things which requires platform specific knowledge. Another critical role of the shim is to report exit state back to containerd, so shims are expected to stick around until the exit state of the container is collected in much the same way that a zombie process continues to exist until its parent collects it (big difference here is the shim takes up resources).

Shims allow the main containerd daemon to detach from the process lifecycle of a container. This enables admins to do things like upgrade containerd without disrupting running containers (though it is a good idea to stop running containers when upgrading from X.Y to X.Y+1). It also is what allows Docker’s [--live-restore](https://docs.docker.com/config/containers/live-restore/) feature to work (though Docker does not currently support custom shims).

Since shims are responsible for platform specific logic, this is where support for [Windows](https://github.com/Microsoft/hcsshim), [FreeBSD](https://github.com/samuelkarp/runj), and of course Linux are added. Here’s an overview of the shims currently officially supported by the containerd maintainers (this is not an exhaustive list of all shims out there):

**io.containerd.runtime.v1.linux**<br>
The original “v1” shim API and shim implementation, designed before containerd hit 1.0. This shim uses runc to execute containers.
This shim only works with cgroups v1.
The v1 shim API is deprecated and will be removed soon (as part of containerd 2.0).

**io.containerd.runc.v1**<br>
Essentially this is the same as `io.containerd.runtime.v1.linux` except it uses the “v2” shim API. Note that “v1” here is referring to the implementation and not the API.
This shim only works with cgroups v1.

**io.containerd.runc.v2**<br>
This is the “v2” implementation of the runc shim with a distinctly different implementation than “v1” and it uses the “v2” shim API.
With this shim, it is actually possible to run more than one container underneath one shim process, this is used by the CRI implementation for Kubernetes to run all containers for a single pod underneath 1 shim.
The v2 shim supports both cgroups v1 and cgroups v2.

**io.containerd.runhcs.v1**<br>
Windows-based shim which manages containers using Window’s HCSv2 API.

Anyone can write a shim and have containerd use it. Shims are specified by name as above and the name is resolved to a binary which containerd looks up in $PATH. The resolution for io.containerd.runc.v2 is containerd-shim-runc-v2, likewise for windows containerd-shim-runhcs-v1.exe (.exe because Windows). The client specifies which shim to use (or else a default will be used) when creating the container.

Example specifying the shim to use in Go:

```go
package main

import (
	"context"

	"github.com/containerd/containerd"
	"github.com/containerd/containerd/namespaces"
	"github.com/containerd/containerd/oci"
	v1opts "github.com/containerd/containerd/pkg/runtimeoptions/v1"
)

func main() {
	ctx := namespaces.WithNamespace(context.TODO(), "default")

	// Create containerd client
	client, err := containerd.New("/run/containerd/containerd.sock")
	if err != nil {
		panic(err)
	}

	// Get the image ref to create the container for
	img, err := client.GetImage(ctx, "docker.io/library/busybox:latest")
	if err != nil {
		panic(err)
	}

	// set options we will pass to the shim (not really setting anything here, but we could)
	var opts v1opts.Options

	// Create a container object in containerd
	cntr, err := client.NewContainer(ctx, "myContainer",
		// All the basic things needed to create the container
		containerd.WithSnapshotter("overlayfs"),
		containerd.WithNewSnapshot("myContainer-snapshot", img),
		containerd.WithImage(img),
		containerd.WithNewSpec(oci.WithImageConfig(img)),
					 
		// Set the option for the shim we want
		containerd.WithRuntime("io.containerd.runc.v1", &opts),
	)
	if err != nil {
		panic(err)
	}

	// cleanup
	cntr.Delete(ctx)
}
```

*Note that WithRuntime takes an `interface{}` as a 2nd argument, which should pass whatever type you want down to the shim. Just make sure your shim knows what that data is and register your type with the [typeurl](https://pkg.go.dev/github.com/containerd/typeurl) package so it can be encoded properly.*

*Also note the above example requires that you have the docker.io/library/busybox:latest image loaded in the default namespace as well as sufficient privileges to mount/unmount the image rootfs.*

Each shim has its own set of options that it supports which you can configure per container. The runc.v2 shim can forward the container’s stdout/stderr to a separate process, set core scheduling, define a custom cgroup for the shim to run in, and many other things.

You can create your own shim to add custom behavior at container execution time.
The shim API consists of both RPC and some binary calls (for creation/teardown of the shim) and can have a backchannel to containerd.

The (v2) shim RPC API is defined [here](https://github.com/containerd/containerd/blob/v1.5.8/runtime/v2/task/shim.proto). 

There are some helpers to implement the shim binary and RPC API’s [here](https://github.com/containerd/containerd/blob/89370122089d9cba9875f468db525f03eaf61e96/runtime/v2/shim/shim.go#L181-L194). 
[Here](https://github.com/containerd/containerd/blob/v1.5.8/cmd/containerd-shim-runc-v2/main.go) is how this is used.
The idea is you implement a go interface and shim.Run will take care of the rest.

If you implement your own shim, you’ll want to watch out for your memory usage since there is a shim process for every container, which adds up quickly.

The shim API is defined in protobuf and looks like a grpc API, however the actual protocol used is a custom protocol called [ttrpc](https://github.com/containerd/ttrpc) which is incompatible with grpc. TTRPC is a bare-bones RPC protocol designed for low memory usage.

Before getting into the RPC calls, it is important to understand that containerd has a “container” object which when you create one is really just data about the container, it does not start anything on the system but stores the container spec into a local database. After a container is created the client creates a “task” from the container object. This is when the shim API’s are called.

This does not cover all the RPC’s, but the overall flow looks like this:

1. The client calls `container.NewTask(…)`, containerd resolves the shim binary from the runtime name specified (or the default); `io.containerd.runc.v2` -> `containerd-shim-runc-v2`

2. containerd starts the shim binary with an argument of start and some flags to define namespace, OCI bundle path, debug mode, unix socket path back to containerd, etc. The current working directory set on this call can be used as a work path for the shim.<br>
At this point the newly created shim process is expected to write a connection string to stdout which will allow containerd to connect to the shim and make API calls. The start command is expected to return as soon as the connection string is ready and the shim is listening for connections.

3. containerd opens a connection to the shim API using the connection string returned from the shim start command.

4.  containerd calls the Create shim RPC with the OCI bundle path and some other options. This should create all the necessary sandboxing and return the pid of the sandboxed process. In the case of runc, we use `runc create --pid-file=<path>` where runc forks off a new process (`runc init`) which will setup the sandbox and then wait for the call to runc start, runc create returns when that is ready. Once runc create returns, runc should have written the pid of the runc-init process to the pid file defined which is what needs to be returned on the API. Clients may use this pid to do things like setup networking in the sandbox (e.g. the network namespace will be found using `/proc/<pid>/ns/net`).<br>
Be aware that the create call may provide a list of mounts that you need to perform to assemble the rootfs (and tear down later).
This request may also have checkpoint information (as in checkpoint/restore) which the shim is expected to make use of if present.

5. The client calls `task.Wait` which triggers containerd to call the `Wait` API on the shim. This is a persistent request that only returns once the container has exited. Note that the container should not be started at this point yet.

6. The client calls `task.Start` which triggers containerd to call the Start shim RPC. This should actually start the container and should return the pid of the container process. Note that the Start RPC is also used for execs (e.g. docker exec), so both the ID of the container and the exec ID (if it is an exec) will be provided. In the runc shim, this calls eitherrunc start or runc exec.

7. At this point the client could request a number of things against the task: `task.ResizePTY` if the task has a TTY, or `task.Kill` to send a signal, etc.<br>
As a note on `task.Exec`, this calls the shim Exec RPC which does not actually exec a process in the container yet, it just registers the exec with the shim, then later the shim `Start` RPC will be called with the exec ID.

8. After the container or exec process exits, the shim `Delete` RPC will be called which should clean up all the resources for the exec or container. For the runc shim, this calls runc delete.

9. containerd calls the `Shutdown` RPC, at which point the shim would be expected to exit.

Another important part of the shim is to fire off lifecycle events back to containerd: `TaskCreate` `TaskStart` `TaskDelete` `TaskExit`, `TaskOOM`, `TaskExecAdded`, `TaskExecStarted`, `TaskPaused`, `TaskResumed`, `TaskCheckpointed`.<br>
These are defined [here](https://github.com/containerd/containerd/blob/v1.5.6/api/events/task.proto).<br>
While clients can get the current state using the State RPC, shims should make a best effort to send these events, and in the correct order.

Shims give containerd plug-ability in the low-level execution of containers. While they are not the only means of executing a container with containerd, it is how the built-in `TaskService` chooses to handle the problem and by extension how Kubernetes pods are run with containerd. They allow containerd to be extended to support other platforms, VM-based runtimes ([firecracker](https://github.com/firecracker-microvm/firecracker-containerd/tree/main/runtime), [kata](https://github.com/kata-containers/kata-containers/tree/2.3.0/src/runtime)), or experiment with other implementations ([systemd](https://github.com/cpuguy83/containerd-shim-systemd-v1)).

Now go have fun and build!
