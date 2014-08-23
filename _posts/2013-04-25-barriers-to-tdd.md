---
layout: post
title: Barriers to TDD
date: 2013-04-25 16:33:50.000000000 +00:00
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '1235348411'
author:
  login: cpuguy83
  email: cpuguy83@gmail.com
  display_name: cpuguy83
  first_name: Brian
  last_name: Goff
---

Any, and hopefully every, developer has probably heard the TDD mantra. I only had to hear it once to know it was the way to go, I'm sure others had to have it repeated over and over before they got it that it really is a better way to do development. If you haven't reached that point yet I'm sure I know a few people with bats and crowbars who can beat it into you some more until you agree too! ;)

Knowing is only half the battle, there are other, seemingly much larger, barriers to entry:

<!--break-->

- minitest
- test-unit
- rspec

- capybara

- factory_girl
- fabrication
- fixtures
- database_cleaner

- spork
- zeus
- guard
- spring

- cucumber
- selenium
- shoulda

- unit tests
- integration tests
- acceptance tests
- model tests
- feature specs
- request specs

- stubs
- mocks

- TDD
- BDD
- TFD

I'm sure this list could be bigger if I tried.
The real problem with this isn't the list. The list is great. It's just that it can be daunting when you are trying to figure things out. I am the sole developer at my company so I don't really have anyone to go to. Going in front of a group of devs and saying you don't test is a bit embarrassing, and indeed going to conferences where TDD is hit hard makes you(me) feel a bit dirty.

In reality you only really need a couple of those gems listed to get started.
_For people reading this who don't do testing, check out these to get started:

* rspec - main test suite
* capybara - when you are ready to test your views
* factorygirl - for test data

Then once you get all that down there is the whole process of actually doing the TDD bit where you are writing tests before you write production code. This can be tricky to get used to doing, and you'll likely quickly realize how poorly written your existing code actually is (because it's not easily testable!)

Some (hopefully?)Pro tips I've picked up:

* Keep your tests fast
* Keep methods short
* In each test you should be able to stub objects that the tested method needs, so...

```ruby
def stuff
# some stuff
  foos = Foo.where(...)
  foos.each { ... }
end
```

<span style="line-height: 1.714285714;font-size: 1rem"><span style="line-height: 1.714285714;font-size: 1rem"> Is not good since now you need some fake Foo records saved in the DB, which makes your tests slow. Instead do:

```ruby
def stuff
  foos = my_foo_finder
  foos.each { ... }
end

def my_foo_finder
  Foo.where(...)
end
```

Could still be better, but at least we can test `#stuff` more easily by stubbing `#my_foo_finder`

* FactoryGirl's `#build_stubbed` is what you most likely want, not `#build`, and certainly not `#create`
* Check out [rspec-given](https://github.com/jimweirich/rspec-given "rspec-given") for a better testing syntax
* Each test block should be testing one thing, though you may be making several assertions on it
* Pick a friend's brain on how they test. You may not agree with them, or they may not be doing it _right_, but get a feel for how other people are doing it
* Stay out of the browser
* Stay out of the irb console
* If you want to see how a method responds, write a failing test so you can see it.. and stay out of the console

Check out [#pairwithme](https://twitter.com/search?q=%23pairwithme&amp;src=hash "#pairwithme") on twitter and [http://www.pairprogramwith.me](http://www.pairprogramwith.me) and pair with someone!
