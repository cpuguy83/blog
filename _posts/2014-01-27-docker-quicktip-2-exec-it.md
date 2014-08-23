---
layout: post
title: 'Docker Quicktip #2: exec it, please!'
date: 2014-01-27 14:26:37.000000000 +00:00
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '2181104940'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

Often when creating a Docker container it is necessary to do a bit of setup before starting the main process you wanted. Sometimes this is just a one-time setup for the first time the container starts (setting up database users, importing data, etc), other times it's setting up the environment to get your process going (as many init.d scripts also do). In any case some script is needed to run before running the main application that the container was created for.

<!--break-->

Let's take an image I recently created: [github: cpuguy83/docker-postgres](https://github.com/cpuguy83/docker-postgres/tree/d59c8578fabfd2e5a417d499836cd1643eac92b4)

**Dockerfile**

```Dockerfile
FROM cpuguy83/ubuntu

RUN apt-get update && apt-get install -y postgresql postgresql-contrib libpq-dev
ADD pg_hba.conf /etc/postgresql/9.1/main/pg_hba.conf
RUN chown postgres.postgres /etc/postgresql/9.1/main/pg_hba.conf
ADD postgresql.conf /etc/postgresql/9.1/main/postgresql.conf
RUN chown postgres.postgres /etc/postgresql/9.1/main/postgresql.conf
RUN sysctl -w kernel.shmmax=4418740224 && /etc/init.d/postgresql start && su postgres -c "createuser -s -d root && psql -c \"ALTER USER root with PASSWORD 'pgpass'; CREATE USER replication REPLICATION LOGIN CONNECTION LIMIT 1 ENCRYPTED PASSWORD 'replpass'\""

EXPOSE 5432
VOLUME /var/lib/postgresql
ADD pg_start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/pg_start.sh

CMD ["/usr/local/bin/pg_start.sh"]
```

**pgstart.sh**

```bash
#!/bin/bash

if [[ ! -z "$MASTER_PORT_5432_TCP_ADDR" ]]; then
	conn_info="host=${MASTER_PORT_5432_TCP_ADDR} user=replication password=${REPLICATION_PASS}"

	echo "primary_conninfo = '${conn_info}'" > /var/lib/postgresql/9.1/main/recovery.conf
	echo "standby_mode = 'on'" >> /var/lib/postgresql/9.1/main/recovery.conf
fi
sysctl -w kernel.shmmax=4418740224
su postgres -c "/usr/lib/postgresql/9.1/bin/postgres -D /var/lib/postgresql/9.1/main -c config_file=/etc/postgresql/9.1/main/postgresql.conf $PG_CONFIG"
```

There are a couple of issues with this, which I'll address in a future post. Here I'll focus on the `CMD` line of the Dockerfile and the last line of pg_start.sh.

First, let's change `CMD` to `ENTRYPOINT` as we learned in the in the [previous article](http://www.tech-d.net/2014/01/27/docker-quicktip-1-entrypoint/ "Docker Quicktip #1: Entrypoint").

The next bit is becoming a pet-peeve of mine when using some of my older images.

When calling postgres we are just doing it directly (well... through `su`, but still directly in terms of the process).

Calling it this way breaks the world. With postgres it might not be too bad but with other apps it may wreck havoc.

As it stands right now if we try to stop this container docker will hang for a few seconds and then just kill it. Go ahead... try it. There is even a setting in Docker for how long to wait before killing the container (docker stop -t Nseconds, default is 10) with `SIGKILL`.

Run `docker logs $container_id` to see the proof.

Why is it doing this? The signals to stop the process are being sent to the startup script and not postgres. I am not trapping signals in my startup script... nor should I be.

So how do I fix it? With `exec`.

Let's change the last line of pg_start to use exec instead:

`exec su postgres -c "/usr/lib/postgresql/9.1/bin/postgres -D /var/lib/postgresql/9.1/main -c config_file=/etc/postgresql/9.1/main/postgresql.conf $PG_CONFIG"`

There we go, docker will now cleanly shutdown my postgres process instead of `SIGKILL`ing it.

Again, run `docker logs $container_id` for the proof.

Docker allows you to proxy all signals (this is enabled by default) to the running process in the container. Need to send HUP to the running process in the container? Send it to the docker container process. You can even use this functionality to run process monitoring on your host for your containerized processes. See [Docker host integration](http://docs.docker.io/en/latest/use/host_integration/) for an example.
