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

  def new_event(records)
    event = ServerSentEvents::Event.new
    event.set("data", (records ? { "Events" => records } : {}).to_json)
    event
  end

  context "#listen" do
    let(:sse_client) { instance_double("ServerSentEvents::Client") }
    let(:listener) { described_class.new(sse_client) }

    it "splits event into records" do
      records = [{ "a" => 3 }, { "b" => "c" }]
      allow(sse_client).to receive(:listen).and_yield(new_event(records))

      expect { |b| listener.listen(&b) }.to yield_successive_args(*records)
    end

    it "splits empty array of records" do
      allow(sse_client).to receive(:listen).and_yield(new_event([]))

      expect { |b| listener.listen(&b) }.not_to yield_control
    end

    it "handles missing event records" do
      allow(sse_client).to receive(:listen).and_yield(new_event(nil))

      expect { |b| listener.listen(&b) }.not_to yield_control
    end
  end
end
