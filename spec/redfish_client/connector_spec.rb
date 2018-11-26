# frozen_string_literal: true

require "excon"
require "json"

require "redfish_client/connector"
require "redfish_client/nil_hash"

RSpec.describe RedfishClient::Connector do
  context ".new" do
    it "raises error for bad URI" do
      expect { described_class.new("bad_uri") }.to raise_error(ArgumentError)
    end

    it "returns a connector instance" do
      expect(described_class.new("http://example.com"))
        .to be_a(described_class)
    end
  end

  context "#get" do
    it "returns response instance" do
      stub_request(:get, "http://example.com/")
      expect(described_class.new("http://example.com").get("/"))
        .to be_a(described_class::Response)
    end

    it "sends GET requests" do
      stubs = Array.new(3) { |n| stub_request(:get, "https://a.org/#{n}") }
      connector = described_class.new("https://a.org")
      3.times { |n| connector.get("/#{n}") }
      stubs.each { |s| expect(s).to have_been_requested.once }
    end

    it "follows redirects" do
      stubs = [
        stub_request(:get, "http://b.com/a")
          .to_return(status: 301, headers: { "Location" => "/b" }),
        stub_request(:get, "http://b.com/b")
          .to_return(status: 302, headers: { "Location" => "/c" }),
        stub_request(:get, "http://b.com/c"),
      ]
      described_class.new("http://b.com").get("/a")
      stubs.each { |s| expect(s).to have_been_requested.once }
    end

    it "does not cache responses by default" do
      stub = stub_request(:get, "https://nocache.si/")
      connector = described_class.new("https://nocache.si")
      4.times { connector.get("/") }
      expect(stub).to have_been_requested.times(4)
    end

    it "caches OK responses when instructed" do
      stub = stub_request(:get, "https://cache.si/")
      connector = described_class.new("https://cache.si", cache: {})
      6.times { connector.get("/") }
      expect(stub).to have_been_requested.once
    end

    it "does not cache non-OK responses" do
      stub = stub_request(:get, "https://badcache.si/").to_return(status: 404)
      connector = described_class.new("https://badcache.si", cache: {})
      5.times { connector.get("/") }
      expect(stub).to have_been_requested.times(5)
    end

    it "caches first OK response" do
      stub = stub_request(:get, "http://mixcache.si/")
        .to_return(status: 404)
        .to_return(status: 200)
        .to_raise("should not reach")
      connector = described_class.new("http://mixcache.si", cache: {})
      expect { 5.times { connector.get("/") } }.not_to raise_error
      expect(stub).to have_been_requested.twice
    end

    it "retries login once if authentication seems bad" do
      stub_request(:get, "http://retry.si/")
        .to_return(status: 401)
        .to_return(status: 200)
        .to_raise("BAD")
      stub_request(:get, "http://retry.si/test")
        .to_return(status: 200)
      connector = described_class.new("http://retry.si", cache: {})
      connector.set_auth_info("user", "pass", "/test")
      connector.get("/")
    end

    it "retries login once if authentication seems bad and get still fails" do
      stub_request(:get, "http://retry.si/")
        .to_return(status: 401)
        .to_return(status: 401)
        .to_raise("BAD")
      stub_request(:get, "http://retry.si/test")
        .to_return(status: 200)
      connector = described_class.new("http://retry.si", cache: {})
      connector.set_auth_info("user", "pass", "/test")
      connector.get("/")
    end
  end

  context "#post" do
    it "returns response instance" do
      stub_request(:post, "http://po.st/here")
      expect(described_class.new("http://po.st").post("/here"))
        .to be_a(described_class::Response)
    end

    it "sends POST requests" do
      stubs = Array.new(4) { |n| stub_request(:post, "http://po.st/#{n}") }
      connector = described_class.new("http://po.st")
      4.times { |n| connector.post("/#{n}") }
      stubs.each { |s| expect(s).to have_been_requested.once }
    end

    it "JSON encodes data" do
      stub = stub_request(:post, "http://json.go/")
        .with(body: { "key" => "value" })
      described_class.new("http://json.go").post("/", "key" => "value")
      expect(stub).to have_been_requested.once
    end

    it "does not cache POST requests" do
      stub = stub_request(:post, "http://no.cache/")
      connector = described_class.new("http://no.cache", cache: {})
      3.times { connector.post("/") }
      expect(stub).to have_been_requested.times(3)
    end
  end

  context "#patch" do
    it "returns response instance" do
      stub_request(:patch, "http://patch.it/")
      expect(described_class.new("http://patch.it").patch("/"))
        .to be_a(described_class::Response)
    end

    it "sends PATCH requests" do
      stubs = Array.new(6) { |n| stub_request(:patch, "http://pt.ch/#{n}") }
      connector = described_class.new("http://pt.ch")
      6.times { |n| connector.patch("/#{n}") }
      stubs.each { |s| expect(s).to have_been_requested.once }
    end

    it "JSON encodes data" do
      stub = stub_request(:patch, "http://enc.me/")
        .with(body: { "patch" => "data" })
      described_class.new("http://enc.me").patch("/", "patch" => "data")
      expect(stub).to have_been_requested.once
    end

    it "does not cache PATCH requests" do
      stub = stub_request(:patch, "http://no.cache.patch/")
      connector = described_class.new("http://no.cache.patch", cache: {})
      2.times { connector.patch("/") }
      expect(stub).to have_been_requested.twice
    end
  end

  context "#delete" do
    it "returns response instance" do
      stub_request(:delete, "http://delete.us/now")
      expect(described_class.new("http://delete.us").delete("/now"))
        .to be_a(described_class::Response)
    end

    it "sends DELETE requests" do
      stubs = Array.new(3) { |n| stub_request(:delete, "http://d.it/#{n}") }
      connector = described_class.new("http://d.it")
      3.times { |n| connector.delete("/#{n}") }
      stubs.each { |s| expect(s).to have_been_requested.once }
    end

    it "does not cache DELETE requests" do
      stub = stub_request(:delete, "http://del.cache/now")
      connector = described_class.new("http://del.cache", cache: {})
      2.times { connector.delete("/now") }
      expect(stub).to have_been_requested.times(2)
    end
  end

  context "#reset" do
    it "invalidates complete cache without parameters" do
      cache = { "/1" => 1, "/2" => 2 }
      connector = described_class.new("http://a.x", cache: cache)
      connector.reset
      expect(cache).to be_empty
    end

    it "invalidates selected cache entry" do
      cache = { "/3" => 3, "/4" => 4, "/5" => 5 }
      connector = described_class.new("http://dummy.do", cache: cache)
      connector.reset("/4")
      expect(cache).to eq("/3" => 3, "/5" => 5)
    end

    it "ignores missing cache entries" do
      cache = { "/6" => 6, "/7" => 7 }
      connector = described_class.new("http://any.tld", cache: cache)
      connector.reset("/8")
      expect(cache).to eq("/6" => 6, "/7" => 7)
    end
  end

  context "#set_auth_info" do
    it "sets basic auth info" do
      connector = described_class.new("http://auth.demo")
      expect { connector.set_auth_info("user", "pass", "/test") }
        .not_to raise_error
    end

    it "sets session auth info" do
      connector = described_class.new("http://auth.demo")
      expect { connector.set_auth_info("user", "pass", "/test", "/sessions") }
        .not_to raise_error
    end
  end

  context "#login" do
    it "authenticates using basic auth" do
      stub = stub_request(:get, "http://auth.demo/test")
        .with(basic_auth: %w[user pass])
      connector = described_class.new("http://auth.demo")
      connector.set_auth_info("user", "pass", "/test")
      connector.login
      expect(stub).to have_been_requested.once
    end

    it "raises error if basic auth fails" do
      stub_request(:get, "http://auth.demo/test").to_return(status: 401)
      connector = described_class.new("http://auth.demo")
      connector.set_auth_info("user", "pass", "/test")
      expect { connector.login }.to raise_error(described_class::AuthError)
    end

    it "authenticates using session auth" do
      stub = stub_request(:post, "http://auth.demo/sessions")
        .to_return(
          body: { "@odata.id" => "456" }.to_json,
          headers: { "X-Auth-Token" => "123" },
          status: 201,
        )

      connector = described_class.new("http://auth.demo")
      connector.set_auth_info("user", "pass", "/test", "/sessions")
      connector.login

      expect(stub).to have_been_requested.once
    end

    it "raises error if session auth fails" do
      stub_request(:post, "http://auth.demo/sessions").to_return(status: 400)

      connector = described_class.new("http://auth.demo")
      connector.set_auth_info("user", "pass", "/test", "/sessions")

      expect { connector.login }.to raise_error(described_class::AuthError)
    end
  end

  context "#logout" do
    it "removes basic auth info from requests" do
      stub_request(:get, "http://auth.demo/test")
        .with(basic_auth: %w[user pass])

      connector = described_class.new("http://auth.demo")
      connector.set_auth_info("user", "pass", "/test")
      connector.login

      connector.logout
    end

    it "removes valid session auth info from requests" do
      stub_request(:post, "http://auth.demo/sessions")
        .to_return(
          body: { "@odata.id" => "/sessions/456" }.to_json,
          headers: { "X-Auth-Token" => "123" },
          status: 201,
        )
      stub = stub_request(:delete, "http://auth.demo/sessions/456")
        .to_return(status: 204)

      connector = described_class.new("http://auth.demo")
      connector.set_auth_info("user", "pass", "/test", "/sessions")
      connector.login
      connector.logout

      expect(stub).to have_been_requested
    end

    it "removes invalid session auth info from requests" do
      stub_request(:post, "http://auth.demo/sessions")
        .to_return(body: { "@odata.id" => "/sessions/456" }.to_json,
                   headers: { "X-Auth-Token" => "123" },
                   status: 201)
        .to_raise("should not be here")
      stub = stub_request(:delete, "http://auth.demo/sessions/456")
        .to_return(status: 401)

      connector = described_class.new("http://auth.demo")
      connector.set_auth_info("user", "pass", "/test", "/sessions")
      connector.login
      connector.logout

      expect(stub).to have_been_requested
    end
  end
end
