# frozen_string_literal: true

require "json"

require "redfish_client/connector"
require "redfish_client/resource"

RSpec.describe RedfishClient::Resource do
  before(:all) do
    r_headers = { "Accept" => "application/json", "OData-Version" => "4.0" }
    w_headers = r_headers.merge("Content-Type" => "application/json")
    host = "example.com"

    Excon.defaults[:mock] = true
    # Stubs are pushed onto a stack - they match from bottom-up. So place
    # least specific stub first in order to avoid staring blankly at errors.
    Excon.stub(
      { path: "/", headers: r_headers, host: host },
      { status: 200,
        body: {
          "@odata.id" => "/",
          "key" => "value",
          "Members" => [{ "@odata.id" => "/sub" }, { "@odata.id" => "/sub1" }],
          "data" => { "a" => "b" },
          "alt_path" => "/alt"
        }.to_json }
    )
    Excon.stub(
      { path: "/", method: :post, headers: w_headers, host: host },
      { status: 201 }
    )
    Excon.stub(
      { path: "/", method: :post, headers: r_headers, host: host },
      { status: 203 }
    )
    Excon.stub(
      { path: "/", method: :patch, headers: r_headers, host: host },
      { status: 401 }
    )
    Excon.stub(
      { path: "/", method: :delete, headers: r_headers, host: host },
      { status: 204 }
    )
    Excon.stub(
      { path: "/missing", headers: r_headers, host: host },
      { status: 404 }
    )
    Excon.stub(
      { path: "/missing", headers: w_headers, host: host },
      { status: 403 }
    )
    Excon.stub(
      { path: "/alt", method: :post, headers: r_headers, host: host },
      { status: 202 }
    )
    Excon.stub(
      { path: "/alt", method: :patch, headers: r_headers, host: host },
      { status: 400 }
    )
    Excon.stub(
      { path: "/sub", headers: r_headers, host: host },
      { status: 200, body: { "@odata.id" => "/sub", "x" => "y" }.to_json }
    )
    Excon.stub(
      { path: "/sub1", headers: r_headers, host: host },
      { status: 200, body: { "w" => "z" }.to_json }
    )
    Excon.stub(
      { path: "/json", method: :post, headers: w_headers, host: host,
        body: { "key" => "value" }.to_json },
      { status: 203 }
    )
    Excon.stub(
      { path: "/pjson", method: :patch, headers: w_headers, host: host,
        body: { "k" => "v" }.to_json },
      { status: 205 }
    )
  end

  after(:all) do
    Excon.stubs.clear
  end

  subject(:resource) do
    connector = RedfishClient::Connector.new("http://example.com")
    described_class.new(connector, oid: "/")
  end

  context ".new" do
    it "wraps hash content" do
      b = { "sample" => "data" }
      r = described_class.new(nil, raw: b)
      expect(r.raw).to eq(b)
    end

    it "fetches resource from oid" do
      connector = RedfishClient::Connector.new("http://example.com")
      r = described_class.new(connector, oid: "/sub")
      expect(r.raw).to eq("@odata.id" => "/sub", "x" => "y")
    end

    it "add resource oid if missing" do
      connector = RedfishClient::Connector.new("http://example.com")
      r = described_class.new(connector, oid: "/sub1")
      expect(r.raw).to eq("@odata.id" => "/sub1", "w" => "z")
    end

    it "errors out on service error" do
      connector = RedfishClient::Connector.new("http://example.com")
      expect { described_class.new(connector, oid: "/missing") }
        .to raise_error(RedfishClient::Resource::NoResource)
    end
  end

  context "#[]" do
    it "retrieves key from resource" do
      expect(resource["key"]).to eq("value")
    end

    it "loads subresources on demand" do
      expect(resource["data"]).to be_a described_class
    end

    it "returns nil on missing key" do
      expect(resource["missing"]).to be_nil
    end
  end

  context "#dig" do
    it "retrieves key from resource" do
      expect(resource.dig("key")).to eq("value")
    end

    it "loads subresources on demand" do
      expect(resource.dig("data")).to be_a described_class
    end

    it "returns nil on missing key" do
      expect(resource.dig("missing")).to be_nil
    end

    it "loads nested keys" do
      expect(resource.dig("data", "a")).to eq("b")
    end

    it "loads nested keys and indices" do
      expect(resource.dig("Members", 0, "x")).to eq("y")
    end

    it "skips any keys after first nil value" do
      expect(resource.dig("Members", 4, "a", "b", 3)).to be_nil
    end
  end

  context "#key?" do
    it "returns true for existing symbol" do
      expect(resource.key?(:data)).to be true
    end

    it "returns true for existing string" do
      expect(resource.key?("data")).to be true
    end

    it "returns false for missing symbol" do
      expect(resource.key?(:missing)).to be false
    end

    it "returns false for missing string" do
      expect(resource.key?("missing")).to be false
    end
  end

  context "#method_missing" do
    it "retrieves key from resource" do
      expect(resource.key).to eq("value")
    end

    it "loads subresources on demand" do
      expect(resource.data).to be_a(described_class)
    end

    it "returns nil on missing key" do
      expect(resource.missing).to be_nil
    end
  end

  context "#respond_to?" do
    it "returns true when accessing existing key" do
      expect(resource.respond_to?("data")).to eq(true)
    end

    it "returns false when accessing non-existing key" do
      expect(resource.respond_to?("bad")).to eq(false)
    end
  end

  context "#raw" do
    it "returns raw wrapped data" do
      expect(resource.Members[0].raw).to eq("@odata.id" => "/sub", "x" => "y")
    end

    it "returns raw wrapped data with added oid" do
      expect(resource.Members[1].raw).to eq("@odata.id" => "/sub1", "w" => "z")
    end
  end

  context "#to_s" do
    it "dumps content to json" do
      expect(JSON.parse(resource.Members[0].to_s))
        .to eq(resource.Members[0].raw)
    end
  end

  context "#post" do
    it "returns response instance" do
      expect(resource.post).to be_a(RedfishClient::Connector::Response)
    end

    it "posts data to the @odata.id endpoint by default" do
      expect(resource.post.status).to eq(203)
    end

    it "posts data to the selected field content" do
      expect(resource.post(field: "alt_path").status).to eq(202)
    end

    it "posts data to the path in presence of field" do
      expect(resource.post(field: "alt_path", path: "/missing").status)
        .to eq(404)
    end

    it "posts data to the selected path" do
      expect(resource.post(path: "/missing").status).to eq(404)
    end

    it "JSON encodes data" do
      params = { path: "/json", payload: { "key" => "value" } }
      expect(resource.post(params).status).to eq(203)
    end
  end

  context "#patch" do
    it "returns response instance" do
      expect(resource.patch).to be_a(RedfishClient::Connector::Response)
    end

    it "posts data to the @odata.id endpoint by default" do
      expect(resource.patch.status).to eq(401)
    end

    it "posts data to the selected field content" do
      expect(resource.patch(field: "alt_path").status).to eq(400)
    end

    it "posts data to the path in presence of field" do
      expect(resource.patch(field: "alt_path", path: "/missing").status)
        .to eq(404)
    end

    it "posts data to the selected path" do
      expect(resource.patch(path: "/missing").status).to eq(404)
    end

    it "JSON encodes data" do
      params = { path: "/pjson", payload: { "k" => "v" } }
      expect(resource.patch(params).status).to eq(205)
    end
  end

  context "#delete" do
    it "returns response instance" do
      expect(resource.delete).to be_a RedfishClient::Connector::Response
    end

    it "posts data to the external endpoint" do
      expect(resource.delete.status).to eq(204)
    end
  end

  context "#headers" do
    it "returns response headers, set at init time" do
      expect(resource.headers).to eq({})
    end
  end
end
