---
layout: post
title: 'Docker Quicktip #7: docker ps --format'
date: 2016-03-27 12:00
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

It's been awhile since I did a quick Docker tip, so I figured I should go ahead
and share one that I know many people will get use out of.

<!--break-->

`docker ps` is a command that absolutely every Docker user uses. When you type it
in you probably, invariably, stretch out your terminal to fit all the super
important information that the command has.

```
$ docker ps
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                                       NAMES
9112d2b6aa30        cpuguy83/configs:hipache       "/usr/local/bin/hipac"   4 months ago        Up 3 days           0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp    prod_hipache_1
849694c39d5b        redis                          "/entrypoint.sh redis"   4 months ago        Up 3 days           6379/tcp                                    prod_hipacheredis_1
a8c4a95147f7        cpuguy83/blog                  "nginx"                  4 months ago        Up 3 days           80/tcp                                      prod_blogwww_1
```

This information is all indeed nice to have, but probably not all of it all the
time. Also probably different people want to see different information. This is
why `docker ps --format ...` was introduced.

Now, you might think "I've seen this, I don't need to see more"... and you might
be right, however stick around and you'll probably find something you didn't know
about that will blow your mind.

For those not in the know, many Docker commands use a `--format` flag which takes
a [go-template](https://golang.org/pkg/text/template/) to customize the output of
the command. `docker inspect` has had this formatting forever... `docker ps`
gained this capability in docker 1.8. A quick example:

```
{% raw %}
$ docker ps --format '{{.Names}}\t{{.Image}}'
{% endraw %}
prod_hipache_1	cpuguy83/configs:hipache
prod_hipacheredis_1	redis
prod_blogwww_1	cpuguy83/blog
```

Not very pretty, but at least it's more awk/greppable.
To make it pretty, we can add `table` to the beginning of the template.

```
{% raw %}
$ docker ps --format 'table {{.Names}}\t{{.Image}}'
{% endraw %}
NAMES                   IMAGE
prod_hipache_1          cpuguy83/configs:hipache
prod_hipacheredis_1     redis
prod_blogwww_1          cpuguy83/blog
```

So that's nice... but what if I told you that you can set a default format so you
don't have to type the same thing in every time, nor have to constantly resize
your terminal, while still being able to override the format from the CLI?

By default, Docker looks for a config file in `~/.docker/config.json`. It stores
some settings here, like auth credentials (which in Docker 1.11 you will be
able to move auth creds elsewhere... more on that in a later post). It can also
store a custom format for `docker ps`.

If you've typed `docker login` before you should have this config file there and
populated with a json hash, we can just add the `docker ps` format configuration
as a top-level item in the hash... here's the configuration that I use:


```json
{% raw %}
{
  "psFormat": "table {{.Names}}\\t{{.Image}}\\t{{.RunningFor}} ago\\t{{.Status}}\\t{{.Command}}"
}
{% endraw %}
```

Which looks like this:


```
$ docker ps
NAMES                   IMAGE                          CREATED             STATUS              COMMAND
prod_hipache_1          cpuguy83/configs:hipache       4 months ago        Up 3 days           "/usr/local/bin/hipac"
prod_hipacheredis_1     redis                          4 months ago        Up 3 days           "/entrypoint.sh redis"
prod_blogwww_1          cpuguy83/blog                  4 months ago        Up 3 days           "nginx"
```

You can also do the same for `docker images`:

```json
{% raw %}
{
  "psFormat": "table {{.Names}}\\t{{.Image}}\\t{{.RunningFor}} ago\\t{{.Status}}\\t{{.Command}}",
  "imagesFormat": "table {{.Repository}}\\t{{.Tag}}\\t{{.ID}}\\t{{.Size}}"
}
{% endraw %}
```

[Read more](https://github.com/docker/docker/blob/master/docs/admin/formatting.md)
for more docs on formatting options for different commands.
