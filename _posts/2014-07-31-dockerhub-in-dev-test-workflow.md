---
layout: post
title: DockerHub in dev-test Workflow
date: 2014-07-31 21:24:19.000000000 +00:00
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

When DockerHub was announced there was a really handy feature added that you may have missed: Webhooks.

With DockerHub you can setup a webhook to call out to an external service once a successful push of a particular image is made (this includes completion of automated builds).

This makes for a nice addition to an existing CI/CD workflow.

<!--break-->

The basic idea is this:

1.  Setup DockerHub automated build
2.  Push code changes to github
3.  DockerHub sees changes and pulls/builds the image
4.  DockerHub calls webhooks for image

The payload DockerHub sends to webhook services is a POST request with some JSON about the image

```json
{
   "push_data":{
      "pushed_at":1385141110,
      "images":[
         "imagehash1",
         "imagehash2",
         "imagehash3"
      ],
      "pusher":"username"
   },
   "repository":{
      "status":"Active",
      "description":"my docker repo that does cool things",
      "is_trusted":false,
      "full_description":"This is my full description",
      "repo_url":"https://registry.hub.docker.com/u/username/reponame/",
      "owner":"username",
      "is_official":false,
      "is_private":false,
      "name":"reponame",
      "namespace":"username",
      "star_count":1,
      "comment_count":1,
      "date_created":1370174400,
      "dockerfile":"my full dockerfile is listed here",
      "repo_name":"username/reponame"
   }
}
```

This can already be integrated with Jenkins using the "[DockerHub](https://github.com/jenkinsci/dockerhub-plugin)" plugin.

I have a demo Rails app here: [https://github.com/cpuguy83/docker-rails-dev-demo](https://github.com/cpuguy83/docker-rails-dev-demo)

This is setup as an automated build with DockerHub: [https://registry.hub.docker.com/u/cpuguy83/docker-rails-dev-demo/](https://registry.hub.docker.com/u/cpuguy83/docker-rails-dev-demo/)

*_It doesn't need to be an automated build for webhooks to work, but with an automated build I can push to GitHub and trigger the build to happen_*

In Jenkins I'm going to setup the trigger to do something on a successful build from DockerHub:

[![Screen Shot 2014-07-31 at 3.57.59 PM](/assets/Screen-Shot-2014-07-31-at-3.57.59-PM.png)](http://www.tech-d.net/wp-content/uploads/2014/07/Screen-Shot-2014-07-31-at-3.57.59-PM.png)]

Then tell it to pull down my new image and run my tests by invoking `docker run cpuguy83/docker-rails-dev-demo test`:

[![Screen Shot 2014-07-31 at 4.00.33 PM](/assets/Screen-Shot-2014-07-31-at-4.00.33-PM.png)](http://www.tech-d.net/wp-content/uploads/2014/07/Screen-Shot-2014-07-31-at-4.00.33-PM.png)

*<sub>_You'll notice in my github repo the Dockerfile is using bin/start.rb to start this container, which itself maps the `test` argument to `rake test`_</sub>

On DockerHub we need to setup the webhook. You can find the webhooks link on the main repo page, on the right-hand column under "Settings"

[![Screen Shot 2014-07-31 at 4.20.18 PM](/assets/Screen-Shot-2014-07-31-at-4.20.18-PM.png)](http://www.tech-d.net/wp-content/uploads/2014/07/Screen-Shot-2014-07-31-at-4.20.18-PM.png)

Add the hook for our Jenkins instance:

[![Screen Shot 2014-07-31 at 4.02.25 PM](/assets/Screen-Shot-2014-07-31-at-4.02.25-PM.png)](http://www.tech-d.net/wp-content/uploads/2014/07/Screen-Shot-2014-07-31-at-4.02.25-PM.png)

<sub>_Change `JENKINS` to your Jenkins host.  The path `/dockerhub-webhook/` must stay as per the Jenkins plugin._</sub>

Away we go, full CI workflow with tests running in the actual real image, tied in with DockerHub as an automated build.

What's really aweomse is this works with your private repos as well!
