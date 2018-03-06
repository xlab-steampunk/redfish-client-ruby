# frozen_string_literal: true

require "redfish_client/connector"

RSpec.describe RedfishClient::Connector do
  context ".new" do
    it "raises error for bad URI" do
      expect do
        described_class.new("bad_uri")
      end.to raise_error(ArgumentError)
    end

    it "returns a connector instance" do
      expect(described_class.new("http://example.com")).to(
        be_a RedfishClient::Connector
      )
    end
  end

  context "#get" do
    before(:all) do
      Excon.defaults[:mock] = true
      # Stubs are pushed onto a stack - they match from bottom-up. So place
      # least specific stub first in order to avoid staring blankly at errors.
      Excon.stub({ host: "example.com" },                     { status: 200 })
      Excon.stub({ host: "example.com", path: "/missing" },   { status: 404 })
      Excon.stub({ host: "example.com", path: "/forbidden" }, { status: 403 })
    end

    after(:all) do
      Excon.stubs.clear
    end

    subject { described_class.new("http://example.com") }

    it "returns response instance" do
      expect(subject.get("/")).to be_a Excon::Response
    end

    it "keeps host stored" do
      expect(subject.get("/missing").status).to eq(404)
      expect(subject.get("/forbidden").status).to eq(403)
      expect(subject.get("/").status).to eq(200)
    end
  end
end
