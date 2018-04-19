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
  # resource also caches responses for later reuse. If we would like to get
  # fresh values from the service, {#reset} call will flush the cache,
  # causing next access to retrieve fresh data.
  class Resource
    # NoODataId error is raised when operation would need OpenData id of the
    # resource to accomplish the task a hand.
    class NoODataId < StandardError; end

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
    # @param content [Hash]
    def initialize(connector, oid: nil, content: nil)
      if oid
        resp = connector.get(oid)
        @content = JSON.parse(resp.data[:body])
        @content["@odata.id"] = oid
        @headers = resp.data[:headers]
      else
        @content = content
      end

      @cache = {}
      @connector = connector
    end

    # Access resource content.
    #
    # This function offers a way of accessing resource data in the same way
    # that hash exposes its content.
    #
    # In addition to accessing values associated with keys, this function can
    # also be used to access members of collection by directly indexing into
    # Members array. This means that `res["Members"][3]` can be shortened into
    # `res[3]`.
    #
    # Accessing non-existent or indexing non-collection resource key will
    # raise `KeyError`. Accessing invalid index will raise `IndexError`.
    #
    # @param attr [String, Integer] key or index for accessing data
    # @return associated value
    def [](attr)
      if attr.is_a?(Integer)
        raise(KeyError, "Not a collection.") unless key?("Members")
        cache("Members").fetch(attr)
      else
        cache(attr)
      end
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
    # Calling `resource.Value` is exactly the same as `resource["Value"]`. The
    # only difference is that accessing non-existent field will raise
    # NoMethodError instead of KeyError as `[]` method does.
    def method_missing(symbol, *args, &block)
      name = symbol.to_s
      key?(name) ? self[name] : super
    end

    def respond_to_missing?(symbol, include_private = false)
      key?(symbol.to_s) || super
    end

    # Clear the cached sub-resources. Next sub-resource access will repopulate
    # the cache.
    def reset
      @cache = {}
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
      @connector.post(get_path(field, path), payload ? payload.to_json : "")
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
      @connector.patch(get_path(field, path), payload ? payload.to_json : "")
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

    def get_path(field, path)
      raise NoODataId if path.nil? and !key?(field)
      path || @content[field]
    end

    def cache(name)
      @cache[name] ||= build_resource(@content.fetch(name))
    end

    def build_resource(data)
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
    end
  end
end
