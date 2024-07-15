# frozen_string_literal: true

require "redfish_client/connector"
require "redfish_client/resource"
require "redfish_client/response"

RSpec.describe RedfishClient::Resource do
  context ".new" do
    it "wraps hash content" do
      b = { "sample" => "data" }
      r = described_class.new(nil, raw: b)
      expect(r.raw).to eq(b)
    end

    it "fetches resource from oid" do
      response = RedfishClient::Response.new(
        200, {}, '{"@odata.id": "/", "a": "b"}'
      )
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/", nil)
        .and_return(response)
      expect(described_class.new(connector, oid: "/").raw)
        .to eq("@odata.id" => "/", "a" => "b")
    end

    it "add resource oid if missing" do
      response = RedfishClient::Response.new(200, {}, '{"a": "b"}')
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/", nil)
        .and_return(response)
      expect(described_class.new(connector, oid: "/").raw)
        .to eq("@odata.id" => "/", "a" => "b")
    end

    it "errors out on service error" do
      response = RedfishClient::Response.new(400, nil, nil)
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/", nil)
        .and_return(response)
      expect { described_class.new(connector, oid: "/") }
        .to raise_error(described_class::NoResource)
    end

    it "respects fragment part of the oid" do
      response = RedfishClient::Response.new(
        200, {}, '{"@odata.id": "/a", "b": {"c": "d"}}'
      )
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/a", nil)
        .and_return(response)
      expect(described_class.new(connector, oid: "/a#b").raw)
        .to eq("@odata.id" => "/a#b", "c" => "d")
    end

    it "properly indexes into array" do
      response = RedfishClient::Response.new(
        200, {}, '{"@odata.id": "/e", "f": [{"g": "h"}]}'
      )
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/e", nil)
        .and_return(response)
      expect(described_class.new(connector, oid: "/e#/f/0").raw)
        .to eq("@odata.id" => "/e#/f/0", "g" => "h")
    end

    it "uses string representation of integers as hash keys" do
      response = RedfishClient::Response.new(
        200, {}, '{"@odata.id": "/a", "5": {"6": "7"}}'
      )
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/a", nil)
        .and_return(response)
      expect(described_class.new(connector, oid: "/a#/5").raw)
        .to eq("@odata.id" => "/a#/5", "6" => "7")
    end
  end

  context "#[]" do
    it "retrieves key from resource" do
      expect(described_class.new(nil, raw: { "k" => "v" })["k"]).to eq("v")
    end

    it "loads subresources on demand" do
      response = RedfishClient::Response.new(200, {}, '{"k": "v"}')
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/s", nil)
        .and_return(response)
      resource = described_class.new(
        connector, raw: { "s" => { "@odata.id" => "/s" } }
      )
      expect(resource["s"].raw).to eq("@odata.id" => "/s", "k" => "v")
    end

    it "returns nil on missing key" do
      expect(described_class.new(nil, raw: {})["missing"]).to be_nil
    end

    it "returns nil on missing reference" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/missing", nil)
        .and_return(RedfishClient::Response.new(404, {}, "{}"))
      raw = { "missing" => { "@odata.id" => "/missing" } }
      expect(described_class.new(connector, raw: raw)["missing"]).to be_nil
    end
  end

  context "#dig" do
    it "retrieves key from resource" do
      resource = described_class.new(nil, raw: { "key" => "value" })
      expect(resource.dig("key")).to eq("value")
    end

    it "loads subresources on demand" do
      response = RedfishClient::Response.new(200, {}, '{"k": "v"}')
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/s", nil)
        .and_return(response)
      resource = described_class.new(
        connector, raw: { "s" => { "@odata.id" => "/s" } }
      )
      expect(resource.dig("s").raw).to eq("@odata.id" => "/s", "k" => "v")
    end

    it "returns nil on missing key" do
      expect(described_class.new(nil, raw: {}).dig("missing")).to be_nil
    end

    it "loads nested keys" do
      resource = described_class.new(nil, raw: { "a" => { "b" => "c" } })
      expect(resource.dig("a", "b")).to eq("c")
    end

    it "loads nested keys and indices" do
      resource = described_class.new(nil, raw: { "a" => [{ "b" => "c" }] })
      expect(resource.dig("a", 0, "b")).to eq("c")
    end

    it "skips any keys after first nil value" do
      expect(described_class.new(nil, raw: {}).dig("x", 4, "a")).to be_nil
    end
  end

  context "#key?" do
    it "returns true for existing symbol" do
      expect(described_class.new(nil, raw: { "d" => 1 }).key?(:d)).to be true
    end

    it "returns true for existing string" do
      expect(described_class.new(nil, raw: { "d" => 1 }).key?("d")).to be true
    end

    it "returns false for missing symbol" do
      expect(described_class.new(nil, raw: {}).key?(:missing)).to be false
    end

    it "returns false for missing string" do
      expect(described_class.new(nil, raw: {}).key?("missing")).to be false
    end
  end

  context "#method_missing" do
    it "retrieves key from resource" do
      expect(described_class.new(nil, raw: { "k" => "v" }).k).to eq("v")
    end

    it "loads subresources on demand" do
      response = RedfishClient::Response.new(200, {}, '{"k": "v"}')
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/s", nil)
        .and_return(response)
      resource = described_class.new(
        connector, raw: { "s" => { "@odata.id" => "/s" } }
      )
      expect(resource.s.raw).to eq("@odata.id" => "/s", "k" => "v")
    end

    it "returns nil on missing key" do
      expect(described_class.new(nil, raw: {}).missing).to be_nil
    end
  end

  context "#respond_to?" do
    it "returns true when accessing existing key" do
      expect(described_class.new(nil, raw: { "a" => 1 }).respond_to?("a"))
        .to eq(true)
    end

    it "returns false when accessing non-existing key" do
      expect(described_class.new(nil, raw: {}).respond_to?("a")).to eq(false)
    end
  end

  context "#raw" do
    it "returns raw wrapped data" do
      expect(described_class.new(nil, raw: { "a" => 3 }).raw).to eq("a" => 3)
    end

    it "returns raw wrapped data with added oid" do
      response = RedfishClient::Response.new(200, {}, '{"a": "b"}')
      connector = double("connector")

      expect(connector).to receive(:request).with(:get, "/", nil)
        .and_return(response)
      expect(described_class.new(connector, oid: "/").raw)
        .to eq("@odata.id" => "/", "a" => "b")
    end
  end

  context "#to_s" do
    it "dumps content to json" do
      expect(described_class.new(nil, raw: { "k" => 5 }).to_s)
        .to eq("{\n  \"k\": 5\n}")
    end
  end

  context "#get" do
    it "sends GET request to the @odata.id endpont by default" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/a", nil)
      described_class.new(connector, raw: { "@odata.id" => "/a" }).get
    end

    it "sends GET request to the endpoint from selected field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/b", nil)
      described_class.new(connector, raw: { "b" => "/b" }).get(field: "b")
    end

    it "sends GET request to the path in presence of field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/c", nil)
      described_class.new(connector, raw: { "b" => "/b" })
        .get(field: "b", path: "/c")
    end

    it "sends GET request to the selected path" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/c", nil)
      described_class.new(connector, raw: {}).get(path: "/c")
    end

    it "returns done monitor instance on 200" do
      response = RedfishClient::Response.new(200, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/d", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).get(path: "/d").done?)
        .to be true
    end

    it "returns in progress monitor instance on 202" do
      response = RedfishClient::Response.new(202, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/e", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).get(path: "/e").done?)
        .to be false
    end
  end

  context "#post" do
    it "sends POST request to the @odata.id endpoint by default" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/a", nil)
      described_class.new(connector, raw: { "@odata.id" => "/a" }).post
    end

    it "sends POST request to the endpoint from selected field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/b", nil)
      described_class.new(connector, raw: { "b" => "/b" }).post(field: "b")
    end

    it "sends POST request to the path in presence of field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/c", nil)
      described_class.new(connector, raw: { "b" => "/b" })
        .post(field: "b", path: "/c")
    end

    it "sends POST request to the selected path" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/c", nil)
      described_class.new(connector, raw: {}).post(path: "/c")
    end

    it "passes payload to the connector" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/c", { 3 => 4 })
      described_class.new(connector, raw: {})
        .post(path: "/c", payload: { 3 => 4 })
    end

    it "returns done monitor instance on 200" do
      response = RedfishClient::Response.new(200, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/f", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).post(path: "/f").done?)
        .to be true
    end

    it "returns done monitor instance on 201" do
      response = RedfishClient::Response.new(201, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/g", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).post(path: "/g").done?)
        .to be true
    end

    it "returns in progress monitor instance on 202" do
      response = RedfishClient::Response.new(202, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:post, "/h", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).post(path: "/h").done?)
        .to be false
    end
  end

  context "#patch" do
    it "sends PATCH request to the @odata.id endpoint by default" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:patch, "/e", nil)
      described_class.new(connector, raw: { "@odata.id" => "/e" }).patch
    end

    it "sends PATCH request to the endpoint from selected field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:patch, "/f", nil)
      described_class.new(connector, raw: { "f" => "/f" }).patch(field: "f")
    end

    it "sends PATCH request to the path in presence of field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:patch, "/h", nil)
      described_class.new(connector, raw: { "g" => "/g" })
        .patch(field: "g", path: "/h")
    end

    it "sends PATCH request to the selected path" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:patch, "/i", nil)
      described_class.new(connector, raw: {}).patch(path: "/i")
    end

    it "passes payload to the connector" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:patch, "/j", { "k" => "v" })
      described_class.new(connector, raw: {})
        .patch(path: "/j", payload: { "k" => "v" })
    end

    it "returns done monitor instance on 200" do
      response = RedfishClient::Response.new(200, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:patch, "/k", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).patch(path: "/k").done?)
        .to be true
    end

    it "returns in progress monitor instance on 202" do
      response = RedfishClient::Response.new(202, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:patch, "/j", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).patch(path: "/j").done?)
        .to be false
    end
  end

  context "#delete" do
    it "sends DELETE request to the @odata.id endpoint by default" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:delete, "/e", nil)
      described_class.new(connector, raw: { "@odata.id" => "/e" }).delete
    end

    it "sends DELETE request to the endpoint from selected field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:delete, "/f", nil)
      described_class.new(connector, raw: { "f" => "/f" }).delete(field: "f")
    end

    it "sends DELETE request to the path in presence of field" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:delete, "/h", nil)
      described_class.new(connector, raw: { "g" => "/g" })
        .delete(field: "g", path: "/h")
    end

    it "sends DELETE request to the selected path" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:delete, "/i", nil)
      described_class.new(connector, raw: {}).delete(path: "/i")
    end

    it "passes payload to the connector" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:delete, "/j", { "k" => "v" })
      described_class.new(connector, raw: {})
        .delete(path: "/j", payload: { "k" => "v" })
    end

    it "returns in progress monitor instance on 202" do
      response = RedfishClient::Response.new(202, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:delete, "/", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).delete(path: "/").done?)
        .to be false
    end

    it "returns done monitor instance on 204" do
      response = RedfishClient::Response.new(204, {}, '{}')
      connector = double("connector")
      expect(connector).to receive(:request).with(:delete, "/", nil)
        .and_return(response)
      expect(described_class.new(connector, raw: {}).delete(path: "/").done?)
        .to be true
    end
  end

  context "#headers" do
    it "returns response headers, set at init time" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/a", nil).and_return(
        RedfishClient::Response.new(200, { "a" => "b" }, "{}"),
      )
      resource = described_class.new(connector, oid: "/a")
      expect(resource.headers).to eq("a" => "b")
    end
  end

  context "#refresh" do
    it "fetches fresh data from API" do
      connector = double("connector")
      expect(connector).to receive(:reset).with("/")
      expect(connector).to receive(:request).with(:get, "/", nil).and_return(
        RedfishClient::Response.new(200, {}, '{"a": 4}'),
        RedfishClient::Response.new(200, {}, '{"b": 3}'),
      )
      resource = described_class.new(connector, oid: "/")

      expect(resource.a).to eq(4)
      expect(resource.b).to be_nil
      resource.refresh
      expect(resource.a).to be_nil
      expect(resource.b).to eq(3)
    end

    it "ignores non-networked resources" do
      resource = described_class.new(nil, raw: { "a" => "b" })
      expect(resource.a).to eq("b")
      resource.refresh
      expect(resource.a).to eq("b")
    end
  end

  context "#wait" do
    it "waits for the operation to terminate" do
      response = RedfishClient::Response.new(202, { "location" => "/m" }, "b")
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/m", nil).and_return(
        RedfishClient::Response.new(200, {}, "c"),
      )
      resp = described_class.new(connector, raw: {}).wait(response, delay: 0)
      expect(resp.status).to eq(200)
      expect(resp.headers).to eq({})
      expect(resp.body).to eq("c")
    end

    it "timeout if number of retries exceeds the threshold" do
      response = RedfishClient::Response.new(202, { "location" => "/m" }, "b")
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/m", nil).and_return(
        RedfishClient::Response.new(202, { "location" => "/m" }, "b"),
      )
      resource = described_class.new(connector, raw: {})
      expect { resource.wait(response, retries: 1, delay: 0) }
        .to raise_error(described_class::Timeout)
    end

    it "does no additional requests if the response was sync" do
      response = RedfishClient::Response.new(200, {}, "b")
      resp = described_class.new(nil, raw: {}).wait(response, delay: 0)
      expect(resp.status).to eq(200)
      expect(resp.headers).to eq({})
      expect(resp.body).to eq("b")
    end
  end
end
