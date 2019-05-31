# frozen_string_literal: true

require "redfish_client/connector"
require "redfish_client/event_listener"
require "redfish_client/resource"
require "redfish_client/root"

RSpec.describe RedfishClient::Root do
  context "#login" do
    it "sets basic auth info and tries to log in" do
      connector = double("connector")
      expect(connector).to receive(:set_auth_info).with(
        "u", "p", "/t", nil
      )
      expect(connector).to receive(:login)

      raw = { "a" => { "@odata.id" => "/t" } }
      described_class.new(connector, raw: raw).login("u", "p")
    end

    it "sets session auth info and tries to log in" do
      connector = double("connector")
      expect(connector).to receive(:set_auth_info).with(
        "u", "p", "/t", "/s"
      )
      expect(connector).to receive(:login)

      raw = {
        "a" => { "@odata.id" => "/t" },
        "Links" => { "Sessions" => { "@odata.id" => "/s" } },
      }
      described_class.new(connector, raw: raw).login("u", "p")
    end
  end

  context "#logout" do
    it "delegates logout to connector" do
      connector = double("connector")
      expect(connector).to receive(:logout)
      described_class.new(connector, raw: {}).logout
    end
  end

  context "#find" do
    it "fetches resource by OData id" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/f", nil).and_return(
          RedfishClient::Response.new(200, nil, '{"f": 8}'),
      )
      expect(described_class.new(connector, raw: {}).find("/f")).not_to be_nil
    end

    it "returns nil on error" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/b", nil).and_return(
        RedfishClient::Response.new(404, nil, '{"f": 8}'),
      )
      expect(described_class.new(connector, raw: {}).find("/b")).to be_nil
    end
  end

  context "#find!" do
    it "fetches resource by OData id" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/f", nil).and_return(
        RedfishClient::Response.new(200, nil, '{"f": 8}'),
      )
      expect { described_class.new(connector, raw: {}).find!("/f") }
        .not_to raise_error
    end

    it "raises exception on error" do
      connector = double("connector")
      expect(connector).to receive(:request).with(:get, "/b", nil).and_return(
        RedfishClient::Response.new(500, nil, '{"f": 8}'),
      )
      expect { described_class.new(connector, raw: {}).find!("/b") }
        .to raise_error(RedfishClient::Resource::NoResource)
    end
  end

  context "#event_listener" do
    it "returns event listener" do
      raw = {
        "EventService" => {
          "ServerSentEventUri" => "https://a.b:12345/dummy",
        },
      }
      expect(described_class.new(nil, raw: raw).event_listener)
        .to be_an_instance_of(RedfishClient::EventListener)
    end

    it "returns nil if SSE is not supported" do
      expect(described_class.new(nil, raw: {}).event_listener).to be_nil
    end
  end
end
