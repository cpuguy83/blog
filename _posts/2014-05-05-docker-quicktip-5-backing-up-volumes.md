---
layout: post
title: 'Docker Quicktip #5: Backing up Volumes'
date: 2014-05-05 14:48:25.000000000 +00:00
categories: []
tags:
- DevOps
- Docker
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '2662480715'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

Data in Docker volumes is generally super important.  In fact if you are doing your containers correctly the stuff in the volumes is the only thing you need to worry about backing up as containers shouldn't be storing anything at all.

So how do you access the data in volumes?

<!--break-->

One way is to use `docker inspect` so see where a container's volumes are stored and use sudo to access that data.  This isn't exactly ideal for a number of reasons:

 - Insane paths

 - Accessing data as root user

 - Creating new data needs to be chowned/chmod'd properly so the container can read/write to it as well

The preferred way is to use `--volumes-from`.  When accessing the volume data you want to make sure you are using the same uid/gid as it was written in, so it's a good idea to use the same image which was used to create that data.  With this method all your data is in the same exact locations as it would normally be.  No need to SSH, nsenter, or nsinit into the container to get at this stuff ([Attaching to a container with Docker 0.9 and libcontainer](http://jpetazzo.github.io/2014/03/23/lxc-attach-nsinit-nsenter-docker-0-9/))...

`docker run -it --rm --entrypoint /bin/sh --volumes-from  my/appimage -c "bash"`

Recently I was building out the backup scheme for our soon to be in-production Docker-based server.  I wanted to be able to just blindly backup all specified volumes without needing to explicitly write out which volumes I wanted, since this could change over time.  We already know the data is important since it's in a volume, so just give it to me.

For now I just want to pull in all volumes from all containers and do with them as I please.

Docker doesn't currently do this with any sort of short-cut like --volumes-from since the volumes needed to be namespaced for container they are in (so as not to overwrite files from other containers).

I started to think about how to implement this feature in Docker, but I really need this now and not month or two from now (when it could possibly be merged in and released).

Technically `--volumes-from` is just bind-mounting the host path of the given volumes into a new container, you could do this manually with "-v /var/lib/docker/path/to/volume:/container/path"

So I thought, well I'll just use `docker inspect` on everything, pipe the output to [jq](http://stedolan.github.io/jq/) and parse the info I needed... thankfully this was a huge pain to do (jq didn't like the dir tree as a hash key).

After fiddling with jq for a bit I remembered that `docker inspect` takes a "--format" option, which is a [go-template](http://golangtutorials.blogspot.com/2011/06/go-templates.html) format.  With this I can massage the output of `docker inspect to be whatever I want it to be, and so here is a little bash function I created to help me do this:

```bash
volume_ars() {
  docker inspect --format='{{ $name := .Name }}{{ range $volPath, $hostPath := .Volumes }}-v {{ $hostPath }}:/volData{{$name}}{{ $volPath }} {{ end }}' $1
}}
```

This little snippet takes a container ID/name as input and spits out all of it's volumes as bind-mount style arguments to be inserted into a `docker run` command, for instance a container with a volume at "/example" would output "-v /volume/path/on/host:/volData//example".

If a container has more than one volume it builds multiple "-v" arguments just as you might if you did it manually.  This output can be directly inserted into a `docker run` command.

And to get all volumes, without getting duplicate host paths (because many of my containers will use the same volumes with `--volumes-from`

```bash
volumes_args() {
  docker inspect --format='{{ $name := .Name }}{{ range $volPath, $hostPath := .Volumes }}-v {{ $hostPath }}:/volData{{$name}}{{ $volPath }} {{ end }}' ${1}
}
volume_hostPaths() {
  docker inspect --format='{{ range $volPath, $hostPath := .Volumes }} {{ $hostPath }} {{ end }}' ${1}
}

volConfig=""
paths=() # store host paths so we can check if it's already used
for container in $(docker ps -a -q); do
  hostPaths=$(volume_hostPaths ${container})
  for hostPath in $hostPaths; do
    match=$(echo "${paths[@]:0}" | grep -o ${hostPath})
    if [[ "${match}" == "" ]]; then
      paths+=(${hostPath})
      volConfig="${volConfig} $(volumes_args ${container})"
    fi
  done
done

docker run -d ${volConfig} --name mybackcontainer my/backup-image
```
