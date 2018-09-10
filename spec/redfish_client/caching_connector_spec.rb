# frozen_string_literal: true

require "redfish_client/caching_connector"

RSpec.describe RedfishClient::CachingConnector do
  before do
    Excon.defaults[:mock] = true
    Excon.stub({ host: "example.com" },                   { status: 200 })
    Excon.stub({ host: "example.com", path: "/missing" }, { status: 404 })
  end

  after do
    Excon.stubs.clear
  end

  def add_stubs
    Excon.stub({ host: "example.com" },                   { status: 401 })
    Excon.stub({ host: "example.com", path: "/missing" }, { status: 403 })
  end

  subject(:connector) { described_class.new("http://example.com") }

  context "#get" do
    it "returns response instance" do
      expect(connector.get("/").status).to eq(200)
      expect(connector.get("/missing").status).to eq(404)

      add_stubs

      expect(connector.get("/").status).to eq(200)
      expect(connector.get("/missing").status).to eq(404)
    end
  end

  context "#reset" do
    it "clears complete cache if path is omitted" do
      expect(connector.get("/").status).to eq(200)
      expect(connector.get("/missing").status).to eq(404)

      add_stubs
      connector.reset

      expect(connector.get("/").status).to eq(401)
      expect(connector.get("/missing").status).to eq(403)
    end

    it "invalidates selected path" do
      expect(connector.get("/").status).to eq(200)
      expect(connector.get("/missing").status).to eq(404)

      add_stubs
      connector.reset(path: "/")

      expect(connector.get("/").status).to eq(401)
      expect(connector.get("/missing").status).to eq(404)
    end
  end
end
