# frozen_string_literal: true

require "redfish_client/connector"
require "redfish_client/event_listener"
require "redfish_client/resource"
require "redfish_client/root"

RSpec.describe RedfishClient::Root do
  context "#find" do
    it "fetches resource by OData id" do
      connector = double("connector")
      expect(connector).to receive(:get).with("/find").and_return(
        RedfishClient::Connector::Response.new(200, nil, '{"f": 8}'),
      )
      expect(described_class.new(connector, raw: {}).find("/find"))
        .not_to be_nil
    end

    it "returns nil on error" do
      connector = double("connector")
      expect(connector).to receive(:get).with("/bad").and_return(
        RedfishClient::Connector::Response.new(404, nil, '{"f": 8}'),
      )
      expect(described_class.new(connector, raw: {}).find("/bad"))
        .to be_nil
    end
  end

  context "#find!" do
    it "fetches resource by OData id" do
      connector = double("connector")
      expect(connector).to receive(:get).with("/find").and_return(
        RedfishClient::Connector::Response.new(200, nil, '{"f": 8}'),
      )
      expect { described_class.new(connector, raw: {}).find!("/find") }
        .not_to raise_error
    end

    it "raises exception on error" do
      connector = double("connector")
      expect(connector).to receive(:get).with("/bad").and_return(
        RedfishClient::Connector::Response.new(500, nil, '{"f": 8}'),
      )
      expect { described_class.new(connector, raw: {}).find!("/bad") }
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
