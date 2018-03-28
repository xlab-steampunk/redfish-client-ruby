# frozen_string_literal: true

require "excon"
require "json"

module RedfishClient
  # Connector serves as a low-level wrapper around HTTP calls that are used
  # to retrieve data from the service API. It abstracts away implementation
  # details such as sending the proper headers in request, which do not
  # change between resource fetches.
  #
  # Library users should treat this class as an implementation detail and
  # use higer-level {RedfishClient::Resource} instead.
  class Connector
    # Default headers, as required by Redfish spec
    # https://redfish.dmtf.org/schemas/DSP0266_1.4.0.html#request-headers
    DEFAULT_HEADERS = {
      "Accept" => "application/json",
      "OData-Version" => "4.0"
    }.freeze

    # Create new connector.
    #
    # @param url [String] base url of the Redfish service
    # @param verify [Boolean] verify SSL certificate of the service
    def initialize(url, verify = true)
      @url = url
      @verify = verify
      @headers = DEFAULT_HEADERS.dup
      @connection = create_connection
    end

    # Add HTTP headers to the requests made by the connector.
    #
    # @param headers [Hash<String, String>] headers to be added
    def add_headers(headers)
      @headers.merge!(headers)
      @connection = create_connection
    end

    # Remove HTTP headers from requests made by the connector.
    #
    # Headers that are not currently set are silently ignored and no error is
    # raised.
    #
    # @param headers [List<String>] headers to remove
    def remove_headers(headers)
      headers.each { |h| @headers.delete(h) }
      @connection = create_connection
    end

    # Issue GET request to service.
    #
    # @param path [String] path to the resource, relative to the base url
    # @return [Excon::Response] response object
    def get(path)
      @connection.get(path: path)
    end

    # Issue POST requests to the service.
    #
    # @param path [String] path to the resource, relative to the base
    # @param body [String] data to be sent over the socket
    # @return [Excon::Response] response object
    def post(path, body = nil)
      params = { path: path }
      params[:body] = body if body
      @connection.post(params)
    end

    # Issue DELETE requests to the service.
    #
    # @param path [String] path to the resource, relative to the base
    # @return [Excon::Response] response object
    def delete(path)
      @connection.delete(path: path)
    end

    private

    def create_connection
      Excon.new(@url, headers: @headers, ssl_verify_peer: @verify)
    end
  end
end
