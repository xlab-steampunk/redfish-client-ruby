# Redfish Ruby Client

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
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/redfish_client.
