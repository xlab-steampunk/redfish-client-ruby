# frozen_string_literal: true

require "excon"
require "json"

require "redfish_client/nil_hash"

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
    # By default, connector performs no caching. If caching is desired,
    # Hash should be used as a cache implementation.
    #
    # It is also possible to pass in custom caching class. Instances of that
    # class should respond to the following four methods:
    #
    #  1. `[](key)`         - Used to access cached content and should return
    #                         `nil` if the key has no associated value.
    #  2. `[]=(key, value)` - Cache `value` under the `key`
    #  3. `clear`           - Clear the complete cache.
    #  4. `delete(key)`     - Invalidate cache entry associated with `key`.
    #
    # @param url [String] base url of the Redfish service
    # @param verify [Boolean] verify SSL certificate of the service
    # @param cache [Object] cache backend
    def initialize(url, verify: true, cache: nil)
      @url = url
      @headers = DEFAULT_HEADERS.dup
      middlewares = Excon.defaults[:middlewares] +
        [Excon::Middleware::RedirectFollower]
      @connection = Excon.new(@url,
                              ssl_verify_peer: verify,
                              middlewares: middlewares)
      @cache = cache || NilHash.new
    end

    # Add HTTP headers to the requests made by the connector.
    #
    # @param headers [Hash<String, String>] headers to be added
    def add_headers(headers)
      @headers.merge!(headers)
    end

    # Remove HTTP headers from requests made by the connector.
    #
    # Headers that are not currently set are silently ignored and no error is
    # raised.
    #
    # @param headers [List<String>] headers to remove
    def remove_headers(headers)
      headers.each { |h| @headers.delete(h) }
    end

    # Issue GET request to service.
    #
    # This method will first try to return cached response if available. If
    # cache does not contain entry for this request, data will be fetched from
    # remote and then cached, but only if the response has an OK (200) status.
    #
    # @param path [String] path to the resource, relative to the base url
    # @return [Excon::Response] response object
    def get(path)
      return @cache[path] if @cache[path]

      @connection.get(path: path, headers: @headers).tap do |r|
        @cache[path] = r if r.status == 200
      end
    end

    # Issue POST requests to the service.
    #
    # @param path [String] path to the resource, relative to the base
    # @param data [Hash] data to be sent over the socket, JSON encoded
    # @return [Excon::Response] response object
    def post(path, data = nil)
      @connection.post(prepare_request_params(path, data))
    end

    # Issue PATCH requests to the service.
    #
    # @param path [String] path to the resource, relative to the base
    # @param data [Hash] data to be sent over the socket
    # @return [Excon::Response] response object
    def patch(path, data = nil)
      @connection.patch(prepare_request_params(path, data))
    end

    # Issue DELETE requests to the service.
    #
    # @param path [String] path to the resource, relative to the base
    # @return [Excon::Response] response object
    def delete(path)
      @connection.delete(path: path, headers: @headers)
    end

    # Clear the cached responses.
    #
    # If path is passed as a parameter, only one cache entry gets invalidated,
    # else complete cache gets invalidated.
    #
    # Next GET request will repopulate the cache.
    #
    # @param path [String] path to invalidate
    def reset(path = nil)
      path.nil? ? @cache.clear : @cache.delete(path)
    end

    private

    def prepare_request_params(path, data)
      params = { path: path }
      if data
        params[:body] = data.to_json
        params[:headers] = @headers.merge("Content-Type" => "application/json")
      else
        params[:headers] = @headers
      end
      params
    end
  end
end
