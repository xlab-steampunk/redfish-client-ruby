# frozen_string_literal: true

require "redfish_client/response"

RSpec.describe RedfishClient::Response do
  context "#done?" do
    it "returns true on non-202 status" do
      [200, 201, 204].each do |s|
        expect(described_class.new(s, {}, "b").done?).to be true
      end
    end

    it "returns false on 202 status" do
      expect(described_class.new(202, {}, "b").done?).to be false
    end
  end

  context "#monitor" do
    it "returns monitor's location on async responses" do
      expect(described_class.new(202, { "location" => "/m" }, "b").monitor)
        .to eq("/m")
    end

    it "returns nil on completed responses" do
      expect(described_class.new(200, { "location" => "/m" }, "b").monitor)
        .to be_nil
    end

    it "returns nil on missing location header" do
      expect(described_class.new(200, {}, "b").monitor).to be_nil
    end

    it "strips everything but path and query string from location header" do
      url = "http://address:12345/path/?query=string"
      expect(described_class.new(202, { "location" =>  url }, "b").monitor)
        .to eq("/path/?query=string")
    end

    it "handles cases where query string is not present" do
      url = "http://address:12345/path"
      expect(described_class.new(202, { "location" =>  url }, "b").monitor)
        .to eq("/path")
    end
  end

  context "#status" do
    it "returns response's status" do
      expect(described_class.new(204, {}, nil).status).to eq(204)
    end
  end

  context "#headers" do
    it "returns response's headers" do
      expect(described_class.new(200, { "k" => "v" }, nil).headers)
        .to eq("k" => "v")
    end
  end

  context "#body" do
    it "returns response's body" do
      expect(described_class.new(200, {}, "body").body).to eq("body")
    end
  end

  context "#to_h" do
    it "converts content into hash" do
      expect(described_class.new(200, {}, "b").to_h)
        .to eq("status" => 200, "headers" => {}, "body" => "b")
    end
  end

  context "#to_s" do
    it "dumps complete response" do
      expect(described_class.new(200, { "a" => "b" }, "body").to_s)
        .to eq("Response[status=200, headers={\"a\"=>\"b\"}, body='body']")
    end
  end

  context ".from_hash" do
    it "deserializes from hash payload" do
      data = { "status" => 202, "headers" => { "a" => "c" }, "body" => "b" }
      response = described_class.from_hash(data)
      expect(response.status).to eq(202)
      expect(response.headers).to eq("a" => "c")
      expect(response.body).to eq("b")
    end
  end
end
