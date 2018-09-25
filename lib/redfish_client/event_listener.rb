# frozen_string_literal: true

require "json"
require "uri"

module RedfishClient
  # EventListener class can be used to stream events from Redfish service. It
  # is a thin wrapper around SSE listener that does the dirty work of
  # splitting each event into its EventRecords and reporting them as separate
  # events.
  class EventListener
    # Create new EventListener instance.
    #
    # @param sse_client [ServerSentEvents::Client] SSE client
    def initialize(sse_client)
      @sse_client = sse_client
    end

    # Stream events from redfish service.
    #
    # Events that this method yields are actually EventRecords, extracted from
    # the actual Redfish Event.
    def listen
      @sse_client.listen do |event|
        split_event_into_records(event).each { |r| yield(r) }
      end
    end

    private

    def split_event_into_records(event)
      JSON.parse(event.data).fetch("Events", [])
    end
  end
end
