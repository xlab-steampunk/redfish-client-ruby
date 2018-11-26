# frozen_string_literal: true

require "server_sent_events"

require "redfish_client/event_listener"
require "redfish_client/resource"

module RedfishClient
  # Root resource represents toplevel entry point into Redfish service data.
  # Its main purpose is to provide authentication support for the API.
  class Root < Resource
    # Find Redfish service object by OData ID field.
    #
    # @param oid [String] Odata id of the resource
    # @return [Resource, nil] new resource or nil if resource cannot be found
    def find(oid)
      find!(oid)
    rescue NoResource
      nil
    end

    # Find Redfish service object by OData ID field.
    #
    # @param oid [String] Odata id of the resource
    # @return [Resource] new resource
    # @raise [NoResource] resource cannot be fetched
    def find!(oid)
      Resource.new(@connector, oid: oid)
    end

    # Return event listener.
    #
    # If the service does not support SSE, this function will return nil.
    #
    # @return [EventListener, nil] event listener
    def event_listener
      address = dig("EventService", "ServerSentEventUri")
      return nil if address.nil?

      EventListener.new(ServerSentEvents.create_client(address))
    end

    # Authenticate against the service.
    #
    # Calling this method will select the appropriate method of authentication
    # and try to login using provided credentials.
    #
    # @param username [String] username
    # @param password [String] password
    # @raise [RedfishClient::AuthenticatedConnector::AuthError] if user
    #   session could not be authenticated
    def login(username, password)
      @connector.set_auth_info(
        username, password, auth_test_path, session_path
      )
      @connector.login
    end

    # Sign out of the service.
    def logout
      @connector.logout
    end

    private

    def session_path
      # We access raw values here on purpose, since calling dig on resource
      # instance would try to download the sessions collection, which would
      # fail since we are not yet logged in.
      raw.dig("Links", "Sessions", "@odata.id")
    end

    def auth_test_path
      raw.values.find { |v| v["@odata.id"] }["@odata.id"]
    end
  end
end
