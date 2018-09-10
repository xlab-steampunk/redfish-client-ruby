# frozen_string_literal: true

require "redfish_client/connector"

module RedfishClient
  # Variant of {RedfishClient::Connector} that caches GET responses.
  class CachingConnector < Connector
    # Create new caching connector.
    #
    # @param url [String] base url of the Redfish service
    # @param verify [Boolean] verify SSL certificate of the service
    def initialize(url, verify = true)
      super
      @cache = {}
    end

    # Issue GET request to service.
    #
    # Request is only issued if there is no cache entry for the existing path.
    #
    # @param path [String] path to the resource, relative to the base url
    # @return [Excon::Response] response object
    def get(path)
      @cache[path] ||= super
    end

    # Clear the cached responses.
    #
    # Next GET request will repopulate the cache.
    def reset(path: nil)
      if path.nil?
        @cache = {}
      else
        @cache.delete(path)
      end
    end
  end
end
