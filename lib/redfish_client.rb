# frozen_string_literal: true

require "redfish_client/connector"
require "redfish_client/root"
require "redfish_client/version"

module RedfishClient
  def self.new(url, prefix: "/redfish/v1", verify: true)
    con = Connector.new(url, verify)
    Root.new(con, oid: prefix)
  end
end
