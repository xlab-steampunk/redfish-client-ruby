# frozen_string_literal: true

require "json"

module RedfishClient
  # Resource is basic building block of Redfish client and serves as a
  # container for the data that is retrieved from the Redfish service.
  #
  # When we interact with the Redfish service, resource will wrap the data
  # retrieved from the service API and offer us dot-notation accessors for
  # values stored.
  #
  # Resource will also load any sub-resource on demand when we access it.
  # For example, if we have a root Redfish resource stored in `root`,
  # accessing `root.SessionService` will automatically fetch the appropriate
  # resource from the API.
  #
  # In order to reduce the amount of requests being sent to the service,
  # resource can also utilise caching connector. If we would like to get
  # fresh values from the service, {#refresh} call will flush the cache and
  # retrieve fresh data from the remote.
  class Resource
    # NoODataId error is raised when operation would need OpenData id of the
    # resource to accomplish the task a hand.
    class NoODataId < StandardError; end

    # NoResource error is raised if the service cannot find requested
    # resource.
    class NoResource < StandardError; end

    # Timeout error is raised if the async request is not handled in due time.
    class Timeout < StandardError; end

    # Headers, returned from the service when resource has been constructed.
    #
    # @return [Hash] resource headers
    attr_reader :headers

    # Raw data that has been used to construct resource by either fetching it
    # from the remote API or by being passed-in as a parameter to constructor.
    #
    # @return [Hash] resource raw data
    attr_reader :raw

    # Get ETag from the response headers or resource property.
    #
    # Redfish services may provide ETag in two ways:
    # 1. HTTP ETag header (preferred)
    # 2. @odata.etag property in the resource (fallback)
    #
    # This method checks both locations, prioritizing the HTTP header.
    #
    # @return [String, nil] ETag value or nil if not present
    def etag
      # Prefer HTTP header (used for If-Match header)
      return @headers["etag"] if @headers&.key?("etag")

      # Fallback to @odata.etag property
      raw["@odata.etag"]
    end

    # Create new resource.
    #
    # Resource can be created either by passing in OpenData identifier or
    # supplying the content (hash). In the first case, connector will be used
    # to fetch the resource data. In the second case, resource only wraps the
    # passed-in hash and does no fetching.
    #
    # @param connector [RedfishClient::Connector] connector that will be used
    #   to fetch the resources
    # @param oid [String] OpenData id of the resource
    # @param raw [Hash] raw content to populate resource with
    # @raise [NoResource] resource cannot be retrieved from the service
    def initialize(connector, oid: nil, raw: nil)
      @connector = connector
      if oid
        initialize_from_service(oid)
      else
        @raw = raw
      end
    end

    # Wait for the potentially async operation to terminate
    #
    # Note that this can be safely called on response from non-async
    # operations where the function will return immediately and without making
    # any additional requests to the service.
    #
    # @param response [RedfishClient::Response] response
    # @param retries [Integer] number of retries
    # @param delay [Integer] number of seconds between retries
    # @return [RedfishClient::Response] final response
    # @raise [Timeout] if the operation did not terminate in time
    def wait(response, retries: 10, delay: 1)
      retries.times do |_i|
        return response if response.done?

        sleep(delay)
        response = get(path: response.monitor)
      end
      raise Timeout, "Async operation did not terminate in allotted time"
    end

    # Access resource content.
    #
    # This function offers a way of accessing resource data in the same way
    # that hash exposes its content.
    #
    # @param attr [String] key for accessing data
    # @return associated value or `nil` if attr is missing
    def [](attr)
      build_resource(raw[attr])
    end

    # Safely access nested resource content.
    #
    # This function is an equivalent of safe navigation operator that can be
    # used with arbitrary keys.
    #
    # Calling `res.dig("a", "b", "c")` is equivalent to `res.a&.b&.c` and
    # `res["a"] && res["a"]["b"] && res["a"]["b"]["c"]`.
    # @params keys [Array<Symbol, String>] sequence of keys to access
    # @return associated value or `nil` if any key is missing
    def dig(*keys)
      keys.reduce(self) { |a, k| a.nil? ? nil : a[k] }
    end

    # Test if resource contains required key.
    #
    # @param name [String, Symbol] key name to test
    # @return [Boolean] inclusion test result
    def key?(name)
      raw.key?(name.to_s)
    end

    # Convenience access for resource data.
    #
    # Calling `resource.Value` is exactly the same as `resource["Value"]`.
    def method_missing(symbol, *_args, &_block)
      self[symbol.to_s]
    end

    def respond_to_missing?(symbol, include_private = false)
      key?(symbol.to_s) || super
    end

    # Pretty-print the wrapped content.
    #
    # @return [String] JSON-serialized raw data
    def to_s
      JSON.pretty_generate(raw)
    end

    # Issue a requests to the selected endpoint.
    #
    # By default, request will be sent to the path, stored in `@odata.id`
    # field. Source field can be changed by specifying the `field` parameter
    # when calling this function. Specifying the `path` argument will bypass
    # the field lookup altogether and issue a request directly to the selected
    # path.
    #
    # If the resource has no lookup field, {NoODataId} error will be raised,
    # since posting to non-networked resources makes no sense and probably
    # indicates bug in library consumer.
    #
    # @param method [Symbol] HTTP method (:get, :post, :patch or :delete)
    # @param field [String, Symbol] path lookup field
    # @param path [String] path to post to
    # @param payload Hash<String, >] data to send
    # @param headers [Hash<String, String>] additional headers for this request only
    # @param etag [String, nil] optional ETag value for If-Match header
    # @return [RedfishClient::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def request(method, field, path, payload = nil, headers = nil, etag = nil)
      @connector.add_headers(headers) if headers&.any?
      target_path = get_path(field, path)

      # Use etag-aware patch method when etag is provided
      if method == :patch && etag
        # Forward ETag value from caller to Connector#patch as keyword argument
        @connector.patch(target_path, payload, etag: etag)
      else
        @connector.request(method, target_path, payload)
      end
    ensure
      @connector.remove_headers(headers) if headers&.any?
    end

    # Issue a GET requests to the selected endpoint.
    #
    # By default, GET request will be sent to the path, stored in `@odata.id`
    # field. Source field can be changed by specifying the `field` parameter
    # when calling this function. Specifying the `path` argument will bypass
    # the field lookup altogether and issue a GET request directly to the
    # selected path.
    #
    # If the resource has no lookup field, {NoODataId} error will be raised,
    # since posting to non-networked resources makes no sense and probably
    # indicates bug in library consumer.
    #
    # @param field [String, Symbol] path lookup field
    # @param path [String] path to post to
    # @param headers [Hash<String, String>] additional headers for this request only
    # @return [RedfishClient::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def get(field: "@odata.id", path: nil, headers: nil)
      request(:get, field, path, nil, headers)
    end

    # Issue a POST requests to the selected endpoint.
    #
    # By default, POST request will be sent to the path, stored in `@odata.id`
    # field. Source field can be changed by specifying the `field` parameter
    # when calling this function. Specifying the `path` argument will bypass
    # the field lookup altogether and POST directly to the requested path.
    #
    # In order to avoid having to manually serialize data to JSON, this
    # function call takes Hash as a payload and encodes it before sending it
    # to the endpoint.
    #
    # If the resource has no lookup field, {NoODataId} error will be raised,
    # since posting to non-networked resources makes no sense and probably
    # indicates bug in library consumer.
    #
    # @param field [String, Symbol] path lookup field
    # @param path [String] path to post to
    # @param payload [Hash<String, >] data to send
    # @param headers [Hash<String, String>] additional headers for this request only
    # @return [RedfishClient::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def post(field: "@odata.id", path: nil, payload: nil, headers: nil)
      request(:post, field, path, payload, headers)
    end

    # Issue a PATCH requests to the selected endpoint.
    #
    # Works exactly the same as the {post} method, but issued a PATCH request
    # to the server.
    #
    # @param field [String, Symbol] path lookup field
    # @param path [String] path to patch
    # @param payload [Hash<String, >] data to send
    # @param headers [Hash<String, String>] additional headers for this request only
    # @param etag [String, nil] optional ETag value for If-Match header
    # @return [RedfishClient::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def patch(field: "@odata.id", path: nil, payload: nil, headers: nil, etag: nil)
      request(:patch, field, path, payload, headers, etag)
    end

    # Issue a PATCH request using the ETag from this resource.
    #
    # This is a convenience method that uses the ETag value obtained when
    # this resource was retrieved from the service. The resource must be
    # fetched via GET (e.g., using `client.find()`) before calling this
    # method, so that the ETag is available in the response headers.
    #
    # If no ETag is present in the headers, this method will perform a
    # regular PATCH without the If-Match header.
    #
    # @example Basic usage
    #   # First, retrieve the resource (GET request with ETag in response)
    #   system = client.find("/redfish/v1/Systems/1")
    #
    #   # Then, update with ETag validation (PATCH with If-Match header)
    #   system.patch_if_match({ "AssetTag" => "Server-001" })
    #
    # @param payload [Hash<String, >] data to send
    # @param field [String, Symbol] path lookup field
    # @param path [String] path to patch
    # @param headers [Hash<String, String>] additional headers for this request only
    # @return [RedfishClient::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def patch_if_match(payload, field: "@odata.id", path: nil, headers: nil)
      current_etag = etag
      patch(field: field, path: path, payload: payload, headers: headers, etag: current_etag)
    end

    # Issue a DELETE requests to the endpoint of the resource.
    #
    # If the resource has no `@odata.id` field, {NoODataId} error will be
    # raised, since deleting non-networked resources makes no sense and
    # probably indicates bug in library consumer.
    #
    # @param field [String, Symbol] path lookup field
    # @param path [String] path to patch
    # @param payload [Hash<String, >] data to send
    # @param headers [Hash<String, String>] additional headers for this request only
    # @return [RedfishClient::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def delete(field: "@odata.id", path: nil, payload: nil, headers: nil)
      request(:delete, field, path, payload, headers)
    end

    # Refresh resource content from the API
    #
    # Caling this method will ensure that the resource data is in sync with
    # the Redfish API, invalidating any caches as necessary.
    def refresh
      return unless self["@odata.id"]

      # TODO(@tadeboro): raise more sensible exception if resource cannot be
      # refreshed.
      @connector.reset(self["@odata.id"])
      initialize_from_service(self["@odata.id"])
    end

    private

    def initialize_from_service(oid)
      url, fragment = oid.split("#", 2)
      resp = wait(get(path: url))
      raise NoResource unless [200, 201].include?(resp.status)

      @raw = get_fragment(JSON.parse(resp.body), fragment)
      @raw["@odata.id"] = oid
      @headers = resp.headers
    end

    def get_fragment(data, fragment)
      # data, /my/0/part -> data["my"][0]["part"]
      parse_fragment_string(fragment).reduce(data) do |acc, c|
        acc[acc.is_a?(Array) ? c.to_i : c]
      end
    end

    def parse_fragment_string(fragment)
      # /my/0/part -> ["my", "0", "part"]
      fragment ? fragment.split("/").reject { |i| i == "" } : []
    end

    def get_path(field, path)
      raise NoODataId if path.nil? && !key?(field)
      path || raw[field]
    end

    def build_resource(data)
      return nil if data.nil?

      case data
      when Hash then build_hash_resource(data)
      when Array then data.collect { |d| build_resource(d) }
      else data
      end
    end

    def build_hash_resource(data)
      if data.key?("@odata.id")
        Resource.new(@connector, oid: data["@odata.id"])
      else
        Resource.new(@connector, raw: data)
      end
    rescue NoResource
      nil
    end
  end
end
