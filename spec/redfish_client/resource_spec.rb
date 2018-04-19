# frozen_string_literal: true

require "json"

require "redfish_client/connector"
require "redfish_client/resource"

RSpec.describe RedfishClient::Resource do
  before(:all) do
    Excon.defaults[:mock] = true
    # Stubs are pushed onto a stack - they match from bottom-up. So place
    # least specific stub first in order to avoid staring blankly at errors.
    Excon.stub({}, { status: 404 })
    Excon.stub(
      { path: "/" },
      { status: 200,
        body: {
          "@odata.id" => "/",
          "key" => "value",
          "Members" => [{ "@odata.id" => "/sub" }, { "@odata.id" => "/sub1" }],
          "data" => { "a" => "b" },
          "alt_path" => "/alt"
        }.to_json }
    )
    Excon.stub({ path: "/alt", method: :post }, { status: 202 })
    Excon.stub({ path: "/", method: :post }, { status: 201 })
    Excon.stub({ path: "/alt", method: :patch }, { status: 400 })
    Excon.stub({ path: "/", method: :patch }, { status: 401 })
    Excon.stub({ path: "/", method: :delete }, { status: 204 })
    Excon.stub(
      { path: "/sub" },
      { status: 200, body: { "@odata.id" => "/sub", "x" => "y" }.to_json }
    )
    Excon.stub(
      { path: "/sub1" },
      { status: 200, body: { "w" => "z" }.to_json }
    )
  end

  after(:all) do
    Excon.stubs.clear
  end

  let(:connector) { RedfishClient::Connector.new("http://example.com") }

  context ".new" do
    it "wraps hash content" do
      b = { "sample" => "data" }
      r = described_class.new(connector, content: b)
      expect(r.raw).to eq(b)
    end

    it "fetches resource from oid" do
      r = described_class.new(connector, oid: "/sub")
      expect(r.raw).to eq("@odata.id" => "/sub", "x" => "y")
    end

    it "add resource oid if missing" do
      r = described_class.new(connector, oid: "/sub1")
      expect(r.raw).to eq("@odata.id" => "/sub1", "w" => "z")
    end
  end

  subject { described_class.new(connector, oid: "/") }

  context "#[]" do
    it "retrieves key from resource" do
      expect(subject["key"]).to eq("value")
    end

    it "indexes into members" do
      expect(subject[0].raw).to eq("@odata.id" => "/sub", "x" => "y")
    end

    it "indexes into members with missing odata id" do
      expect(subject[1].raw).to eq("@odata.id" => "/sub1", "w" => "z")
    end

    it "loads subresources on demand" do
      expect(subject["data"]).to be_a described_class
    end

    it "errors out on missing key" do
      expect { subject["missing"] }.to raise_error(KeyError)
    end

    it "errors out on indexing non-collection" do
      expect { subject[0][0] }.to raise_error(KeyError)
    end

    it "errors out on index out of range" do
      expect { subject[3] }.to raise_error(IndexError)
    end
  end

  context "#key?" do
    it "returns true for existing symbol" do
      expect(subject.key?(:data)).to be true
    end

    it "returns true for existing string" do
      expect(subject.key?("data")).to be true
    end

    it "returns false for missing symbol" do
      expect(subject.key?(:missing)).to be false
    end

    it "returns false for missing string" do
      expect(subject.key?("missing")).to be false
    end
  end

  context "#method_missing" do
    it "retrieves key from resource" do
      expect(subject.key).to eq("value")
    end

    it "loads subresources on demand" do
      expect(subject.data).to be_a described_class
    end

    it "errors out on missing key" do
      expect { subject.missing }.to raise_error(NoMethodError)
    end
  end

  context "#respond_to?" do
    it "returns true when accessing existing key" do
      expect(subject.respond_to?("data")).to eq(true)
    end

    it "returns false when accessing non-existing key" do
      expect(subject.respond_to?("bad")).to eq(false)
    end
  end

  context "#raw" do
    it "returns raw wrapped data" do
      expect(subject[0].raw).to eq("@odata.id" => "/sub", "x" => "y")
    end

    it "returns raw wrapped data with added oid" do
      expect(subject[1].raw).to eq("@odata.id" => "/sub1", "w" => "z")
    end
  end

  context "#to_s" do
    it "dumps content to json" do
      expect(JSON.parse(subject[0].to_s)).to eq(subject[0].raw)
    end
  end

  context "#reset" do
    it "clears cached entries" do
      expect(subject.reset).to eq({})
    end
  end

  context "#post" do
    it "returns response instance" do
      expect(subject.post).to be_a Excon::Response
    end

    it "posts data to the @odata.id endpoint by default" do
      expect(subject.post.status).to eq(201)
    end

    it "posts data to the selected field content" do
      expect(subject.post(field: "alt_path").status).to eq(202)
    end

    it "posts data to the selected path" do
      expect(subject.post(path: "/mis").status).to eq(404)
    end

    it "posts data to the path in presence of field" do
      expect(subject.post(field: "alt_path", path: "/mis").status).to eq(404)
    end

    it "posts data to the selected path" do
      expect(subject.post(path: "/missing").status).to eq(404)
    end
  end

  context "#patch" do
    it "returns response instance" do
      expect(subject.patch).to be_a Excon::Response
    end

    it "posts data to the @odata.id endpoint by default" do
      expect(subject.patch.status).to eq(401)
    end

    it "posts data to the selected field content" do
      expect(subject.patch(field: "alt_path").status).to eq(400)
    end

    it "posts data to the selected path" do
      expect(subject.patch(path: "/mis").status).to eq(404)
    end

    it "posts data to the path in presence of field" do
      expect(subject.patch(field: "alt_path", path: "/mis").status).to eq(404)
    end

    it "posts data to the selected path" do
      expect(subject.patch(path: "/missing").status).to eq(404)
    end
  end

  context "#delete" do
    it "returns response instance" do
      expect(subject.delete).to be_a Excon::Response
    end

    it "posts data to the external endpoint" do
      expect(subject.delete.status).to eq(204)
    end
  end
end
