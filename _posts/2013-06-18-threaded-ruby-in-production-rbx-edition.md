---
layout: post
title: Threaded Ruby in Production - Rbx edition
date: 2013-06-18 02:12:00.000000000 +00:00
categories: []
tags:
- rails
- rbx
- rubinius
- ruby
- threads
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '1408687594'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

At enVu we use Ruby and Rails to bring together various pieces of 3rd party software to make them integrate a bit better with our business requirements.

<!--break-->

Until recently we used MRI Ruby 1.9.3 + Phusion Passenger, which worked well for us but were limited by MRI's [GIL](http://ablogaboutcode.com/2012/02/06/the-ruby-global-interpreter-lock/ "GIL"). Being a startup on a limited budget means we also have limited resources.

**Looking at the alternatives without a GIL**

**_JRuby_**
I first turned to JRuby. I'd had some experience with it in the past for a small project, but nothing for something as large as a Rails project. What I already knew I didn't like was using Java. I hate setting up the VM and being limited the the configured VM's environment (max RAM and all). Then there was having to find replacements for C-Ext libraries.
This is not to say I don't like JRuby, I do at least for interfacing with Java libraries and I greately appreciate all the work the JRuby guys are doing. I decided I did not want to move forward with making the move over.

**_Rubinius_**
I'd been looking at Rubinius on and off. The first thing I'd noticed was absolutely no updates to the official [Rubinius Website](http://rubini.us "Rubinius Website") in quite some time (something which has now changed), which put me off a little since it seemed like there was no activity, but then looking at the Github repo seemed to paint a different picture entirely. After doing a bit more research on it I decided to give it a shot.

Rubinius &lt; 2.0 still has a GIL and 2.0 is currently, at the time of this writing, in the release candidate phase. You should not be put off by this, except in some edge cases it should prove to be stable for you, but do test first! Unlike JRuby, it supports C-Extensions, so you should be able to use all the gems you are familiar with and are currently using.
The biggest issue you are going to have is ensuring that your code and the gems you are using is threadsafe.
If you do run into an issue create an issue on Github and hop on to #rubinius on Freenode.

To pair with your GIL-free environment you'll also want to use a threaded application server, [Puma.io](http://puma.io "Puma") fits the bill perfectly. It is extremely fast and uses few resources.

Also check out [Sidekiq](http://mperham.github.io/sidekiq/ "Sidekiq") for fast, threaded background job processing.

All in all, aside from fixing any thread safety issues in your app, Rubinius should be a near drop-in replacement for MRI.

Under MRI I was using 2.5GB of RAM and generally sat around 3.0 System load (5min) - MRI, Sidekiq(mutli-process), Passenger.
With Rubinius that RAM usage has dropped to 1.5GB and 1.75 System load (5min) - Rubinius, Sidekiq, Puma

It is really exciting to see such a move to fully threaded Ruby environments!

Also wanted to give a big thank you to @dbussink for all the help in fixing our rbx+sidekiq issues.
