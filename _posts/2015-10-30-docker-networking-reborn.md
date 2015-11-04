---
layout: post
title: 'Docker Networking: Reborn'
date: 2015-10-30 16:00
tags:
- Docker
- Devops
- Orchestration
- Clustering
- Networking
status: publish
type: post
published: true
author:
  email: cpuguy83@gmail.com
  first_name: Brian
  last_name: Goff
---

Forget everything you thought knew about Docker networking. It's all changed,
brand new and shiney, and yet oddly familiar.
Docker 1.9 is coming and it will change the way you do container networking.

You may have seen some
[experiements](/2015/09/15/experimenting-with-native-docker-tooling/) now I'll
show you the real deal.

<!--break-->

Docker 1.9 includes for the first time the concept of the
"Container Network Model". Read more on
[CNM](https://blog.docker.com/2015/04/docker-networking-takes-a-step-in-the-right-direction-2/).
Basically, CNM is about creating small, micro-segmented networks for groups of
containers to communicate over.

![Container Network Model](https://blog.docker.com/media/2015/04/cnm-model.jpg)

These networks are highly configurable, and yet easy to setup using just the
defaults.

```
$ docker network create frontend
a639a457122020faa69a4ab906bc33217c9c6d73048f3dbbb69e53dbe5e0952c
$ docker run -d --name rose --net=frontend busybox top
c1fa2dc7fa3a412b52b53f5facd25ba11e99c362d77be8cea4ff49f3d5e2cafc
```

And there, we have a container running on the `frontend` network.
Let's talk to it.

```
$ docker run --rm --net=frontend busybox ping -c 4 rose
PING rose (172.19.0.2): 56 data bytes
64 bytes from 172.19.0.2: seq=0 ttl=64 time=0.122 ms
64 bytes from 172.19.0.2: seq=1 ttl=64 time=0.078 ms
64 bytes from 172.19.0.2: seq=2 ttl=64 time=0.098 ms
64 bytes from 172.19.0.2: seq=3 ttl=64 time=0.241 ms
```

So we attached a 2nd container to the `frontend` network and used the built-in
discovery to reach the container named `rose` via ping.
Now let's take a look at the network details:

```
$ docker network inspect frontend
[
    {
        "Name": "frontend",
        "Id": "a639a457122020faa69a4ab906bc33217c9c6d73048f3dbbb69e53dbe5e0952c",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {}
            ]
        },
        "Containers": {
            "c1fa2dc7fa3a412b52b53f5facd25ba11e99c362d77be8cea4ff49f3d5e2cafc": {
                "EndpointID": "976bab21d4a11cd21d5d1c1560f67f39ef15245662aeacf097eb1d5c148ed748",
                "MacAddress": "02:42:ac:13:00:02",
                "IPv4Address": "172.19.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {}
    }
]
```

Like the familiar command `docker inspect`, `docker network inspect` provides
low-level details about the network, including attached containers.

There is a lot that you can customize when creating a network, here's what is
currently available:

```
  --aux-address=map[]      auxiliary ipv4 or ipv6 addresses used by Network driver
  -d, --driver="bridge"    Driver to manage the Network
  --gateway=[]             ipv4 or ipv6 Gateway for the master subnet
  --help=false             Print usage
  --ip-range=[]            allocate container ip from a sub-range
  --ipam-driver=default    IP Address Management Driver
  -o, --opt=map[]          set driver specific options
  --subnet=[]              subnet in CIDR format that represents a network segment
```

Let's talk about the "--driver" option. This option lets you specify the driver
which is responsible for managing the network. Docker ships with 2 drivers:

- bridge -- This driver provides the same sort of networking via veth bridge
devices that prior versions of docker use, it is the default.
- overlay -- Not to be confused with the "overlay" storage driver (thanks overlayfs),
this driver provides native multi-host networking for docker clusters. When using
swarm, this is the default driver.

Other drivers can be used via plugins.

There is also `--ipam-driver`, which allows you to customize how IP addresses are
assigned. The only driver included with Docker is the same/equivelant of what it
has always done.
However, I should note as I know a lot of people want DHCP support, there are a
number of people working on a DHCP IPAM driver.


Back to setting things up...
Let's create a new network and attach our container to it. Yes, let's add a
2nd network to the running container.

```
$ docker network create backend
09733cac7890edca439cdc3d476b4cd1959e44065217aa581d359575b8d2288f
$ docker network connect backend rose
$ docker network inspect backend

    {
        "name": "backend",
        "id": "09733cac7890edca439cdc3d476b4cd1959e44065217aa581d359575b8d2288f",
        "scope": "local",
        "driver": "bridge",
        "ipam": {
            "driver": "default",
            "config": [
                {}
            ]
        },
        "containers": {
            "c1fa2dc7fa3a412b52b53f5facd25ba11e99c362d77be8cea4ff49f3d5e2cafc": {
                "endpoint": "438730c588915dd54dc694efdb3a15c77bc5e86c744f5f87a65f6ac46b43e5ad",
                "mac_address": "02:42:ac:14:00:02",
                "ipv4_address": "172.20.0.2/16",
                "ipv6_address": ""
            }
        },
        "options": {}
    }
]
```

Cool, now let's check the container's network settings.

```
$ docker inspect -f {{ "'{{ json .NetworkSettings "}}}}' rose
{
  "Bridge": "",
  "SandboxID": "b600bebe1e2bb6dee92335e6acfe49215c30c4964d7a982711ec12c6acca3309",
  "HairpinMode": false,
  "LinkLocalIPv6Address": "",
  "LinkLocalIPv6PrefixLen": 0,
  "Ports": {},
  "SandboxKey": "/var/run/docker/netns/b600bebe1e2b",
  "SecondaryIPAddresses": null,
  "SecondaryIPv6Addresses": null,
  "EndpointID": "",
  "Gateway": "",
  "GlobalIPv6Address": "",
  "GlobalIPv6PrefixLen": 0,
  "IPAddress": "",
  "IPPrefixLen": 0,
  "IPv6Gateway": "",
  "MacAddress": "",
  "Networks": {
    "backend": {
      "EndpointID": "438730c588915dd54dc694efdb3a15c77bc5e86c744f5f87a65f6ac46b43e5ad",
      "Gateway": "172.20.0.1",
      "IPAddress": "172.20.0.2",
      "IPPrefixLen": 16,
      "IPv6Gateway": "",
      "GlobalIPv6Address": "",
      "GlobalIPv6PrefixLen": 0,
      "MacAddress": "02:42:ac:14:00:02"
    },
    "frontend": {
      "EndpointID": "976bab21d4a11cd21d5d1c1560f67f39ef15245662aeacf097eb1d5c148ed748",
      "Gateway": "172.19.0.1",
      "IPAddress": "172.19.0.2",
      "IPPrefixLen": 16,
      "IPv6Gateway": "",
      "GlobalIPv6Address": "",
      "GlobalIPv6PrefixLen": 0,
      "MacAddress": "02:42:ac:13:00:02"
    }
  }
}
```

Cool, so what's this look like inside the container?

```
$ docker exec rose ifconifg
eth0      Link encap:Ethernet  HWaddr 02:42:AC:13:00:02
          inet addr:172.19.0.2  Bcast:0.0.0.0  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:27 errors:0 dropped:0 overruns:0 frame:0
          TX packets:16 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:2238 (2.1 KiB)  TX bytes:1208 (1.1 KiB)

eth1      Link encap:Ethernet  HWaddr 02:42:AC:14:00:02
          inet addr:172.20.0.2  Bcast:0.0.0.0  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:16 errors:0 dropped:0 overruns:0 frame:0
          TX packets:8 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:1296 (1.2 KiB)  TX bytes:648 (648.0 B)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

Just like I connected it to a network, I can also disconnect, and the corrosponding
interface, will be removed.

```
$ docker network disconnect backend rose
```

The intention of these networks is to segregate services such that the only things
on a network are things that need to talk to each other. This means in practice
you should have lots of networks with small amounts of containers in them.
Networks are all isolated from each other.
If two containers are not on the same network, they cannot talk.

A typical example would be a load balancer, a web app front end, a web app
backend, and a database.

[![cnm-demo](/assets/cnm-demo.png)](/assets/cnm-demo.png)


In Swarm the default network driver is the overlay driver (when creating networks).
This allows containers on separate hosts to be able to communicate with each other
just as you would expect them to on the same host.
This driver uses VxLAN to encapsulate traffic, and requires kernels >= 3.16.

To provide this ability, you must supply Docker with a K/V store so Docker engines
can discover each other, this is provided as a daemon flag.

```
$ docker daemon --help | grep cluster
  --cluster-advertise=                 Address or interface name to advertise
  --cluster-store=                     Set the cluster store
  --cluster-store-opt=map[]            Set cluster store options
```

That is all you need to setup multi-host networking in Docker. In fact it's
extremely easy to setup and configure a docker cluster with this functionality
ready to go. Try it out for yourself:

**This script requires docker-machine**

```bash
#!/bin/sh

set -e

create() {
  echo Setting up kv store
  docker-machine create -d virtualbox kvstore > /dev/null && \
  docker $(docker-machine config kvstore) run -d --net=host progrium/consul --server -bootstrap-expect 1

  # store the IP address of the kvstore machine
  kvip=$(docker-machine ip kvstore)

  echo Creating cluster nodes
  docker-machine create -d virtualbox \
    --engine-opt "cluster-store consul://${kvip}:8500" \
    --engine-opt "cluster-advertise eth1:2376" \
    --virtualbox-boot2docker-url https://github.com/boot2docker/boot2docker/releases/download/v1.9.0/boot2docker.iso \
    --swarm \
    --swarm-master \
    --swarm-image swarm:1.0.0 \
    --swarm-discovery consul://${kvip}:8500 \
    swarm-demo-1 > /dev/null &

  for i in 2 3; do
    docker-machine create -d virtualbox \
      --engine-opt "cluster-store consul://${kvip}:8500" \
      --engine-opt "cluster-advertise eth1:2376" \
      --swarm \
      --swarm-discovery consul://${kvip}:8500 \
      --virtualbox-boot2docker-url https://github.com/boot2docker/boot2docker/releases/download/v1.9.0/boot2docker.iso \
      swarm-demo-$i > /dev/null &
  done
  wait
}

teardown() {
  docker-machine rm kvstore &
  for i in 1 2 3; do
    docker-machine rm -f swarm-demo-$i &
  done
  wait
}

case $1 in
  up)
    create
    ;;
  down)
    teardown
    ;;
  *)
    echo "I literally can't even..."
    exit 1
    ;;
esac
```

We can run the script and instantly have a 3-node cluster with multi-host networking
ready to go.

```
$ ./swarminate up
<!-- output truncated -->
# load the config for the swarm master into the env
$ eval $(docker-machine env --swarm swarm-demo-1)
```

Now we can verify we are talking to a swarm cluster

```
$ docker info
Containers: 4
Images: 3
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 3
 swarm-demo-1: 192.168.99.139:2376
  └ Containers: 2
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0-rc4 (TCL 6.4); master : 4fab4a2 - Sat Oct 31 17:00:18 UTC 2015, provider=virtualbox, storagedriver=aufs
 swarm-demo-2: 192.168.99.137:2376
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0-rc4 (TCL 6.4); master : 4fab4a2 - Sat Oct 31 17:00:18 UTC 2015, provider=virtualbox, storagedriver=aufs
 swarm-demo-3: 192.168.99.138:2376
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0-rc4 (TCL 6.4); master : 4fab4a2 - Sat Oct 31 17:00:18 UTC 2015, provider=virtualbox, storagedriver=aufs
CPUs: 3
Total Memory: 3.064 GiB
Name: 0a49f1e5d537
```

Now lets setup an overlay network:

```
$ docker network create multi # The overlay driver is default on swarm
5580acd70dd89d58cecd16df769ace923c91226ce9d6e22828ec83efd8a25c46
$ docker network inspect multi
[
    {
        "Name": "multi",
        "Id": "5580acd70dd89d58cecd16df769ace923c91226ce9d6e22828ec83efd8a25c46",
        "Scope": "global",
        "Driver": "overlay",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {}
            ]
        },
        "Containers": {},
        "Options": {}
    }
]
```

Let's get some containers running, we'll use swarm constraints to make sure
containers are fired up on separate nodes for this demo. Now, we don't have to use
swarm here, these docker engines will allow containers to communicate without swarm,
but for simplicity in demoing I will use swarm to schedule/aggregate the containers.

**Note that container names on a multi-host network must be globally unique across
each engine connected to this network**

```
$ docker run -d --name demo1 --net=multi -e constraint:node==swarm-demo-1 busybox top
eaf4bc7e2f99fd3b82e7647ec449cd515cc1d53dffe3a037fa877121ce6f6508
$ docker run -d --name demo2 --net=multi -e constraint:node==swarm-demo-2 busybox top
d6c7897e92626519ec143f9c464759493249a75730301d226f385f177f4fe507
$ docker run -d --name demo3 --net=multi -e constraint:node==swarm-demo-3 busybox top
92615d47c901197b9d24c83b31a8be1a8909353895bf9623e5b5508187d1cf05
$ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
92615d47c901        busybox             "top"               6 minutes ago       Up 6 minutes                            swarm-demo-3/demo3
d6c7897e9262        busybox             "top"               7 minutes ago       Up 7 minutes                            swarm-demo-2/demo2
eaf4bc7e2f99        busybox             "top"               8 minutes ago       Up 8 minutes                            swarm-demo-1/demo1
```

Now we have all 3 containers running, each on separate nodes, all connected to
the network named "multi".

```
$ docker exec demo1 sh -c 'ping -c 1 demo2; ping -c 1 demo3'
PING demo2 (10.0.1.3): 56 data bytes
64 bytes from 10.0.1.3: seq=0 ttl=64 time=0.549 ms

--- demo2 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.549/0.549/0.549 ms
PING demo3 (10.0.1.4): 56 data bytes
64 bytes from 10.0.1.4: seq=0 ttl=64 time=0.398 ms

--- demo3 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.398/0.398/0.398 ms
$
$ docker exec demo2 sh -c 'ping -c 1 demo1; ping -c 1 demo3'
PING demo1 (10.0.1.2): 56 data bytes
64 bytes from 10.0.1.2: seq=0 ttl=64 time=0.643 ms

--- demo1 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.643/0.643/0.643 ms
PING demo3 (10.0.1.4): 56 data bytes
64 bytes from 10.0.1.4: seq=0 ttl=64 time=0.690 ms

--- demo3 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.690/0.690/0.690 ms
$
$ docker exec demo3 sh -c 'ping -c 1 demo1; ping -c 1 demo2'
PING demo1 (10.0.1.2): 56 data bytes
64 bytes from 10.0.1.2: seq=0 ttl=64 time=7.559 ms

--- demo1 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 7.559/7.559/7.559 ms
PING demo2 (10.0.1.3): 56 data bytes
64 bytes from 10.0.1.3: seq=0 ttl=64 time=0.407 ms

--- demo2 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.407/0.407/0.407 ms
$
```

Just like with the bridge networks, you shold use these overlay networks with
small groups of containers that actually need to communicate with each other.

The network endpoints for overlay networks are not currently secured, so you
should make sure that the channel being overlayed is secured.  
In the future, probably Docker 1.10, these endpoints will be optionally secured.

Containers can be part of as many networks as needed. They can be part of local
bridge networks and overlay networks at the samme time. You can use external
plugins to provide other networking options, such as macvlan, ipvlan, weave, etc.

When you are done playing with the cluster above, you can clean it all up like so:
```
$ ./swarminate down
```

When using the new networking features, the `links` feature is no longer available.
The intention here is to use the built-in service discovery rather than links.
The one thing missing here is being able to alias a container's name like you can
do with links, e.g. `--link mydb:db`. This is coming.  
Likewise, the `--icc=false` option does not apply to the new networking features,
instead you should segregate containers by network, as containers that don't share
a network cannot communicate.
Both of these features are still available on the default bridge network, so you
can continue to use them if you prefer.

The new networking features in Docker 1.9 are a major step forward, and there is
still more to come!  
