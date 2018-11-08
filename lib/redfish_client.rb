# frozen_string_literal: true

require "redfish_client/connector"
require "redfish_client/nil_hash"
require "redfish_client/root"
require "redfish_client/version"

module RedfishClient
  # Create new Redfish API client.
  #
  # @param url [String] base URL of Redfish API
  # @param prefix [String] Redfish API prefix
  # @param verify [Boolean] verify certificates for https connections
  # @param use_cache [Boolean] cache API responses
  def self.new(url, prefix: "/redfish/v1", verify: true, use_cache: true)
    cache = (use_cache ? Hash : NilHash).new
    con = Connector.new(url, verify: verify, cache: cache)
    Root.new(con, oid: prefix)
  end
end
