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
  # fresh values from the service, {#reset} call will flush the cache,
  # causing next access to retrieve fresh data.
  class Resource
    # NoODataId error is raised when operation would need OpenData id of the
    # resource to accomplish the task a hand.
    class NoODataId < StandardError; end

    # NoResource error is raised if the service cannot find requested
    # resource.
    class NoResource < StandardError; end

    # Headers, returned from the service when resource has been constructed.
    attr_reader :headers

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
    # @param content [Hash] content to populate resource with
    # @raise [NoResource] resource cannot be retrieved from the service
    def initialize(connector, oid: nil, content: nil)
      @connector = connector

      if oid
        initialize_from_service(oid)
      else
        @content = content
      end
    end

    # Access resource content.
    #
    # This function offers a way of accessing resource data in the same way
    # that hash exposes its content.
    #
    # @param attr [String] key for accessing data
    # @return associated value or `nil` if attr is missing
    def [](attr)
      build_resource(@content[attr])
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
      @content.key?(name.to_s)
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

    # Clear the cached sub-resources.
    #
    # This method is a no-op if connector in use does not support caching.
    def reset
      @connector.reset if @connector.respond_to?(:reset)
    end

    # Access raw JSON data that resource wraps.
    #
    # @return [Hash] wrapped data
    def raw
      @content
    end

    # Pretty-print the wrapped content.
    #
    # @return [String] JSON-serialized raw data
    def to_s
      JSON.pretty_generate(@content)
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
    # @return [Excon::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def post(field: "@odata.id", path: nil, payload: nil)
      @connector.post(get_path(field, path), payload)
    end

    # Issue a PATCH requests to the selected endpoint.
    #
    # Works exactly the same as the {post} method, but issued a PATCH request
    # to the server.
    #
    # @param field [String, Symbol] path lookup field
    # @param path [String] path to patch
    # @param payload [Hash<String, >] data to send
    # @return [Excon::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def patch(field: "@odata.id", path: nil, payload: nil)
      @connector.patch(get_path(field, path), payload)
    end

    # Issue a DELETE requests to the endpoint of the resource.
    #
    # If the resource has no `@odata.id` field, {NoODataId} error will be
    # raised, since deleting non-networked resources makes no sense and
    # probably indicates bug in library consumer.
    #
    # @return [Excon::Response] response
    # @raise  [NoODataId] resource has no OpenData id
    def delete
      @connector.delete(get_path("@odata.id", nil))
    end

    private

    def initialize_from_service(oid)
      resp = @connector.get(oid)
      raise NoResource unless resp.status == 200

      @content = JSON.parse(resp.data[:body])
      @content["@odata.id"] = oid
      @headers = resp.data[:headers]
    end

    def get_path(field, path)
      raise NoODataId if path.nil? && !key?(field)
      path || @content[field]
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
        Resource.new(@connector, content: data)
      end
    rescue NoResource
      nil
    end
  end
end
