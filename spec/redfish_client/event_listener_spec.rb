# frozen_string_literal: true

require "json"
require "server_sent_events/event"

require "redfish_client/event_listener"

RSpec.describe RedfishClient::EventListener do
  context ".new" do
    it "creates new instance" do
      expect(described_class.new("http://sample.url"))
        .to be_an_instance_of(described_class)
    end
  end

  context "#listen" do
    it "splits event into records" do
      event = ServerSentEvents::Event.new.tap do |e|
        e.set("data", '{"Events": [{"a": 3}, {"b": "c"}]}')
      end
      sse_client = instance_double("ServerSentEvents::Client")
      allow(sse_client).to receive(:listen).and_yield(event)

      expect { |b| described_class.new(sse_client).listen(&b) }
        .to yield_successive_args({ "a" => 3 }, { "b" => "c" })
    end

    it "splits empty array of records" do
      event = ServerSentEvents::Event.new.tap do |e|
        e.set("data", '{"Events": []}')
      end
      sse_client = instance_double("ServerSentEvents::Client")
      allow(sse_client).to receive(:listen).and_yield(event)

      expect { |b| described_class.new(sse_client).listen(&b) }
        .not_to yield_control
    end

    it "handles missing event records" do
      event = ServerSentEvents::Event.new.tap { |e| e.set("data", "{}") }
      sse_client = instance_double("ServerSentEvents::Client")
      allow(sse_client).to receive(:listen).and_yield(event)

      expect { |b| described_class.new(sse_client).listen(&b) }
        .not_to yield_control
    end
  end
end
