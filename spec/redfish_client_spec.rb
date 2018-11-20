# frozen_string_literal: true

require "json"

require "redfish_client"

RSpec.describe RedfishClient do
  it "has a version number" do
    expect(RedfishClient::VERSION).not_to be nil
  end

  context ".new" do
    it "creates new root resource with default prefix" do
      stub_request(:get, "http://example.com/redfish/v1")
        .to_return(status: 200, body: '{"a": "b"}')
      expect(described_class.new("http://example.com").a).to eq("b")
    end

    it "creates new root resource with custom prefix" do
      stub_request(:get, "http://example.com/custom")
        .to_return(status: 200, body: '{"c": "d"}')
      expect(described_class.new("http://example.com", prefix: "/custom").c)
        .to eq("d")
    end

    it "creates caching connector by default" do
      stub_request(:get, "http://example.com/redfish/v1")
        .to_return(status: 200, body: '{"e": "f"}')
        .to_raise("Should not be here")

      client = described_class.new("http://example.com")
      3.times { expect(client.e).to eq("f") }
    end

    it "can create non-caching connector" do
      stub_request(:get, "http://example.com/redfish/v1")
        .to_return(status: 200, body: '{"g": {"@odata.id": "/h"}}')
      stub_request(:get, "http://example.com/h")
        .to_return(status: 200, body: '{"i": "j"}')
        .to_return(status: 200, body: '{"i": "k"}')

      client = described_class.new("http://example.com", use_cache: false)
      expect(client.g.i).to eq("j")
      expect(client.g.i).to eq("k")
    end
  end
end
