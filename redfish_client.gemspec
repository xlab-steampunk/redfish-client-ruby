
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "redfish_client/version"

Gem::Specification.new do |spec|
  spec.name          = "redfish_client"
  spec.version       = RedfishClient::VERSION
  spec.authors       = ["Tadej Borovšak"]
  spec.email         = ["tadej.borovsak@xlab.si"]

  spec.summary       = "Simple Redfish client library"
  spec.homepage      = "https://github.com/xlab-steampunk/redfish-client-ruby"
  spec.license       = "Apache-2.0"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.1"

  spec.add_runtime_dependency "excon", ">= 0.71", "< 2"
  spec.add_runtime_dependency "server_sent_events", "~> 0.1"

  spec.add_development_dependency "rake", ">= 11.0"
  spec.add_development_dependency "rspec", ">= 3.7"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "webmock", "~> 3.4"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "rubocop", "~> 0.54.0"
  spec.add_development_dependency "pry"
end
