# frozen_string_literal: true

module RedfishClient
  # Response struct.
  #
  # This struct is returned from the methods that interact with the remote API.
  class Response
    attr_reader :status
    attr_reader :headers
    attr_reader :body

    def initialize(status, headers, body)
      @status = status
      @headers = headers
      @body = body
    end

    def done?
      status != 202
    end

    def monitor
      done? ? nil : headers["location"]
    end

    def to_h
      { "status" => status, "headers" => headers, "body" => body }
    end

    def to_s
      "Response[status=#{status}, headers=#{headers}, body='#{body}']"
    end

    def self.from_hash(data)
      new(*data.values_at("status", "headers", "body"))
    end
  end
end
