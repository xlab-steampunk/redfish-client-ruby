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

  before(:all) do
    Excon.defaults[:mock] = true
    # Stubs are pushed onto a stack - they match from bottom-up. So place
    # least specific stub first in order to avoid staring blankly at errors.
    Excon.stub({ host: "example.com" },                     { status: 200 })
    Excon.stub({ host: "example.com", path: "/missing" },   { status: 404 })
    Excon.stub({ host: "example.com", path: "/forbidden" }, { status: 403 })
    Excon.stub({ host: "example.com", path: "/post", method: :post },
               { status: 201 })
    Excon.stub(
      { host: "example.com",
        path: "/json",
        method: :post,
        body: { "key" => "value" }.to_json },
      { status: 203 }
    )
    Excon.stub({ host: "example.com", path: "/patch", method: :patch },
               { status: 202 })
    Excon.stub(
      { host: "example.com",
        path: "/pjson",
        method: :patch,
        body: { "k" => "v" }.to_json },
      { status: 205 }
    )
    Excon.stub({ host: "example.com", path: "/delete", method: :delete },
               { status: 204 })
    Excon.stub({ host: "example.com", path: "/redirect", method: :get },
               { status: 302, headers: { "Location" => "/" } })
  end

  after(:all) do
    Excon.stubs.clear
  end

  subject(:connector) { described_class.new("http://example.com") }

  context "#get" do
    it "returns response instance" do
      expect(connector.get("/")).to be_a Excon::Response
    end

    it "keeps host stored" do
      expect(connector.get("/missing").status).to eq(404)
      expect(connector.get("/forbidden").status).to eq(403)
      expect(connector.get("/").status).to eq(200)
    end

    it "follows redirect" do
      expect(connector.get("/redirect").status).to eq(200)
    end
  end

  context "#post" do
    it "returns response instance" do
      expect(connector.post("/post")).to be_a Excon::Response
    end

    it "send post request" do
      expect(connector.post("/post").status).to eq(201)
    end

    it "JSON encodes data" do
      expect(connector.post("/json", "key" => "value").status).to eq(203)
    end
  end

  context "#patch" do
    it "returns response instance" do
      expect(connector.patch("/patch")).to be_a Excon::Response
    end

    it "send post request" do
      expect(connector.patch("/patch", '{"key": "value"}').status).to eq(202)
    end

    it "JSON encodes data" do
      expect(connector.patch("/pjson", "k" => "v").status).to eq(205)
    end
  end

  context "#delete" do
    it "returns response instance" do
      expect(connector.delete("/delete")).to be_a Excon::Response
    end

    it "send post request" do
      expect(connector.delete("/delete").status).to eq(204)
    end
  end
end
