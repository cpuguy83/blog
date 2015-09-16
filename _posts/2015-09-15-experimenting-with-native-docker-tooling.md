---
layout: post
title: 'Experimenting with Native Docker tooling'
date: 2015-09-15 12:00
tags:
- Docker
- Devops
- Orchestration
- Clustering
status: publish
type: post
published: true
author:
  email: cpuguy83@gmail.com
  first_name: Brian
  last_name: Goff
---

Using Docker over the last two years has been a wonderful experience. It is not
always perfect. I've certainly had to write new tools (and use other's tools) to
deal with a missing or not-fully-baked features for my own needs. However, this
has served to allow us to focus on the next level of problems in administering
systems, be it for local dev envs, production clusters, and everything in
between.

Very often when talking to other developers they all agree they like the Docker
model, but the path from a simple dev env to a proudction cluster (even a small one)
is unclear.
Indeed, I tend to agree, there has not been a simple way to set this up without
rolling your own tooling (which I've done a lot of).

The Docker community has been working on new tools and API's to help fill in some
of those gaps and aleviate some of the headaches with some supporting tooling
like compose, swarm, and machine, but still these aren't really production ready
yet nor the integration points completely figured out.
That is not to say don't use these tools, I use them every day. I don't
create a Digital Ocean droplet without doing it through docker-machine, for
instance.

Thankfully, this is somthing being worked on! I'd like to show you some of it.
It is still **QUITE** rough around the edges, but I'd expect to see some major
improvements soon, possibly even in time for for the Docker Engine 1.9 release (October).
Without further ado, let's take a look!

<!--break-->

**Reminder**: This is all experimental and does not reflect the final feature-set/API
but is intended to give a small glimpse into what is coming.

There is a tremendous effort to support multi-host networking natively in Docker.
This follows the whole "batteries included but swappable" mantra, and in this
case the included batteries is support for vxlan overlay networks with support
for plugins via [libnetwork](https://github.com/docker/libnetwork)

Let's setup a cluster!

**Note**: As it turns out, it's quite difficult to test out the experimental
Docker Engine build with boot2docker, so I'm going to use Digital Ocean + Debian
which is far easier to customize.
Also, each part of the script would be concatenated with the previous to make
one complete script.

First, we need a KV store that our docker nodes can talk to:

```bash
#!/bin/bash

if [ -z $DIGITALOCEAN_ACCESS_TOKEN ]; then
  echo "Enter your digital ocean API key:"
  read -s DIGITALOCEAN_ACCESS_TOKEN
fi
export DIGITALOCEAN_ACCESS_TOKEN=$DIGITALOCEAN_ACCESS_TOKEN

set -e

echo setting up kv store
docker-machine create -d digitalocean kvstore && \
(
    eval $(docker-machine env kvstore)
    docker run -d --net=host progrium/consul --server -bootstrap-expect 1
)

# store the IP address of the kvstore machine
kvip=$(docker-machine ip kvstore)
```

Now let's get a swarm token to setup the cluster, and setup the first node.
Normally I would prefer to setup all nodes in parallel, however since the
discovery portion of the multi-host networking isn't fully integrated we need to
know the IP address of the 1st node (or really any node) to give to the subsequent
nodes for serf.

The vxlan/overlay network driver requires at least kernel 3.16, so we need to
specify debian 8 instead of the default ubuntu setup.

```bash
# create a cluster id
swarm_token=$(docker $(docker-machine config kvstore) run --rm swarm create)

install_url=https://experimental.docker.com

# Create node 1
docker-machine create -d digitalocean \
  --swarm \
  --swarm-master \
  --swarm-discovery token://${swarm_token} \
  --engine-label "com.docker.network.driver.overlay.bind_interface=eth0" \
  --engine-opt "default-network overlay:multihost" \
  --engine-opt "kv-store consul:${kvip}:8500" \
  --engine-install-url ${install_url} \
  --digitalocean-image "debian-8-x64" \
  swarm-demo-1 || echo > /dev/null
```

This will instruct docker-machine to create a new droplet on Digital Ocean with
Debian Jessie, use the experimental repos to install docker, and sets up the
network overlay driver.
It also sets up the swarm manager and swarm agent (in a container) on this node with the
pre-created cluster key.
We have to `|| echo > /dev/null` because one, we `set -e` above, which
instructs bash to exit on error, and two because the engine installation above
yields an error even though everything is ok... this is a bug in the docker-machine
provisioner for Debian.

Once this is done we can setup the other two nodes in parallel:

```bash
docker-machine create -d digitalocean \
  --engine-label "com.docker.network.driver.overlay.bind_interface=eth0" \
  --engine-label="com.docker.network.driver.overlay.neighbor_ip=$(docker-machine ip swarm-demo-1)" \
  --engine-opt "default-network overlay:multihost" \
  --engine-opt "kv-store consul:${kvip}:8500" \
  --engine-install-url ${install_url} \
  --digitalocean-image "debian-8-x64" \
  swarm-demo-2 &

docker-machine create -d digitalocean \
  --engine-label "com.docker.network.driver.overlay.bind_interface=eth0" \
  --engine-label="com.docker.network.driver.overlay.neighbor_ip=$(docker-machine ip swarm-demo-1)" \
  --engine-opt "default-network overlay:multihost" \
  --engine-opt "kv-store consul:${kvip}:8500" \
  --engine-install-url ${install_url} \
  --digitalocean-image "debian-8-x64" \
  swarm-demo-3 &

  wait
```

Now, I would normally want to use the `--swarm` flag here so machine automatically
sets these up with our swarm... however the network overlay driver requires that
container names must be unique across all nodes... and docker-machine just uses
the container name `swarm-agent` with the `--swarm` flag, as such this creates
a naming conflict... so we'll have to enable swarm on these nodes manually for
now.

```bash
(
  # setup swarm on node 2
  eval $(docker-machine env swarm-demo-2)
  docker run -d \
    --name=swarm-agent2 \
    swarm:latest \
    join \
    --advertise=$(docker-machine ip swarm-demo-2):2376 \
    token://${swarm_token}
)

(
  # setup swarm on node 3
  eval $(docker-machine env swarm-demo-3)
  docker run -d \
    --name=swarm-agent3 \
    swarm:latest \
    join \
    --advertise=$(docker-machine ip swarm-demo-3):2376 \
    token://${swarm_token}
)
```

So now we have a 3 node swarm cluster with multi-host networking enabled.
With this, docker will automatically connect a container named `foo` on node 2,
to a container named `bar` on node 3 with no extra setup.

```bash
eval $(docker-machine env --swarm swarm-demo-1)
docker run -d --name foo -e constraint:node==swarm-demo-2 busybox top
docker run --rm --name bar -e constraint:node==swarm-demo-3 busybox ping -c 1 foo
PING foo (172.17.0.52) 56(84) bytes of data.
64 bytes from 172.17.0.52: icmp_seq=1 ttl=64 time=0.039 ms

--- foo ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.039/0.039/0.039/0.000 ms
```

Ideally one could use compose against this cluster and everything just works...
and it does, with a couple of caveats:

1. Currently swarm will co-schedule containers with links, so you must either be
ok with linked containers being on the same node (pointless), or use the container
names that compose generates (also horrible).
2. Machine only knows that node 1 is in the cluster, so you must always use the
env setup from that node as such `eval $(docker-machine env --swarm swarm-demo-1)`

As you can see, this is clearly very rough around the edges still, but we are
very close to being really easy to setup and maintain a docker cluster. Give it
a shot for yourself!
