# frozen_string_literal: true

require "json"

require "redfish_client"

RSpec.describe RedfishClient do
  before(:all) do
    Excon.defaults[:mock] = true
    Excon.stub(
      { path: "/redfish/v1" },
      { status: 200, body: { "key" => "default_val" }.to_json }
    )
    Excon.stub(
      { path: "/custom" },
      { status: 200, body: { "key" => "custom_val" }.to_json }
    )
  end

  after(:all) do
    Excon.stubs.clear
  end

  it "has a version number" do
    expect(RedfishClient::VERSION).not_to be nil
  end

  context ".new" do
    it "creates new root resource with default prefix" do
      client = described_class.new("http://example.com")
      expect(client.key).to eq("default_val")
    end

    it "creates new root resource with custom prefix" do
      client = described_class.new("http://example.com", prefix: "/custom")
      expect(client.key).to eq("custom_val")
    end
  end
end
