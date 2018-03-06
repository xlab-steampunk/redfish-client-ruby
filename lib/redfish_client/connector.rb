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
      @connection = Excon.new(url, headers: DEFAULT_HEADERS)
    end

    # Issue GET request to service.
    #
    # @param path [String] path to the resource, relative to the base url
    # @return [Excon::Response] response object
    def get(path)
      @connection.get(path: path)
    end
  end
end
