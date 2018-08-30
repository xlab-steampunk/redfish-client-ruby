# Redfish Ruby Client

[![Build Status](https://travis-ci.org/xlab-si/redfish-client-ruby.svg?branch=master)](https://travis-ci.org/xlab-si/redfish-client-ruby)
[![Maintainability](https://api.codeclimate.com/v1/badges/884ef5e8d68dff90567f/maintainability)](https://codeclimate.com/github/xlab-si/redfish-client-ruby/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/884ef5e8d68dff90567f/test_coverage)](https://codeclimate.com/github/xlab-si/redfish-client-ruby/test_coverage)
[![Dependency Status](https://beta.gemnasium.com/badges/github.com/xlab-si/redfish_client.svg)](https://beta.gemnasium.com/projects/github.com/xlab-si/redfish_client)
[![security](https://hakiri.io/github/xlab-si/redfish_client/master.svg)](https://hakiri.io/github/xlab-si/redfish_client/master)


This repository contains source code for redfish_client gem that can be used
to connect to Redfish services.


## Installation

Add this line to your application's Gemfile:

    gem "redfish_client"

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redfish_client


## Usage

Minimal program that uses this gem would look something like this:

    require "redfish_client"

    root = RedfishClient.new("https://localhost:8000",
                             prefix: "/redfish/v1",
                             verify: false)
    puts root
    root.login("username", "password")
    puts root.Systems
    root.logout


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `bundle exec rake spec` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To create new release, increment the version number, commit the change, tag
the commit and push tag to the GitHub. Travis CI will pick from there on and
create new release, publishing it on https://rubygems.org.


## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/xlab-si/redfish_client.
