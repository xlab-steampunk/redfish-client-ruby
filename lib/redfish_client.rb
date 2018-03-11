require "redfish_client/connector"
require "redfish_client/root"
require "redfish_client/version"

module RedfishClient
  def self.new(url, prefix = "/redfish/v1")
    con = Connector.new(url)
    Root.new(con, oid: prefix)
  end
end
