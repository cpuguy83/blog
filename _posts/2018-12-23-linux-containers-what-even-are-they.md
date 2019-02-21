---
layout: post
title: 'Linux containers, what even are they?'
date: 2018-12-23 13:00
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

I see a lot of people say a lot of things about containers which either are just completely false or show a clear misunderstanding of the technology, so I figured I would write this to point people towards.

*Note*: This article is specifically about Linux containers, and not anything to do with container images, distribution, orchestration, or any of thse things.

<!--break-->

So… I’ll just dive right in…

First, in Linux, containers don’t exist. They aren’t a real construct in the kernel, just a term we have collectively started to use to describe a pattern for managing a process.

Let’s take a familiar example, nginx. What happens when you start nginx? Well, it sets up some stuff typically as the root user, namely a TCP server on port 80, and then it changes to an unprivileged user. Why does it do this? On Linux, a normal, unprivileged (non-root) user does not have the ability to bind to port 80, or any port below 1024 (you can get around this, but I did say “normal”). So nginx starts as the root user, binds to port 80, then changes the user it’s running as to an unprivileged user by using setuid(2). In essence, nginx is dropping capabilities in order to help ensure if nginx is compromised by some future bug then at least the user it is running as doesn’t have many privileges…. and congratulations, you basically have a leaky, translucent container…ok, a stretch in terms of calling it a container, but I stand by it.

Now, let’s suppose nginx took some extra steps (it doesn’t currently AFAIK, but I haven’t checked) than just running as a non-privileged user. It could:

* Limit the processes that nginx can see to just what it created… because why would nginx need to see any other processes on the system? unshare(CLONE_NEWPID)… and boom nginx now sees itself as PID 1 and any processes it creates will follow suite… but of course it’s not actually PID 1, just how nginx will see it from now on.

* Apply resource controls to make sure it can’t consume too much CPU/memory. You could imagine seeing these options directly in the nginx config… it could do it’s own accounting (and probably this would be horrible), or it can just write the limits to /sys/fs/cgroups and Linux will take care of accounting and enforcement.

* Limit the system calls that nginx can make to just the calls which are expected (bind, accept, read, write, probably a few others)… do this by applying filter rules with seccomp(2). Prevents an attacker from coercing nginx into doing unexpected things.

* Limit filesystem access to just the files that nginx reads from and writes to…. chroot(2) doesn’t generally work here because it needs /etc/nginx and /var/log, typically (of course one could configure this)… so an apparmor or selinux profile (probably seccomp could do this as well). Or if you want to chroot (because why not?) you could bind mount /etc/nginx and /var/log to something like /tmp/nginxroot and chroot to /tmp/nginxroot… now nginx will only see the locations it actually needs in addition to not even having permissions to access other files in case there is an issue with the chroot (note that Docker and other container runtimes are using pivot_root instead of chroot)

At this point, if nginx was doing all these things it would have locked itself down pretty well, future exploits in nginx would have a hard time doing very much on the system or even finding out very much information about the system and that leaky, translucent container is getting a bit more air tight and a lot harder to see through.

So literally every Linux application can do these same techniques to protect users from itself. After all, this is exactly the reason nginx uses setuid(2) to change users, this is all just doing that much more to protect users. In fact, Chromium does some of this ([https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux_sandboxing.md](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux_sandboxing.md)). It all has very low overhead and adds several security boundaries.

What if you didn’t have to rely on these programs for doing this (and for that matter doing it right)? This is what Linux containers are all about, forcing a program to run with these security boundaries in place. When you docker run a container image, all this (and much more) is being setup for you without having to modify the existing application. When you use docker exec, this is actually creating a 2nd “container” that just happens to share resources with the first one.

This is all “native” to Linux. It’s all enforced by the kernel. It doesn’t require emulation or machine virtualization. Applications don’t have compatibility issues with these techniques (assuming you haven’t restricted something that the application actually does need).
