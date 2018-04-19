# frozen_string_literal: true

require "redfish_client/resource"

module RedfishClient
  # Root resource represents toplevel entry point into Redfish service data.
  # Its main purpose is to provide authentication support for the API.
  class Root < Resource
    # AuthError is raised if the user session cannot be created.
    class AuthError < StandardError; end

    # Token authentication header.
    AUTH_HEADER = "X-Auth-Token"

    # Authenticate against the service.
    #
    # Calling this method will try to create new session on the service using
    # provided credentials. If the session creation fails, {AuthError} will be
    # raised.
    #
    # @param username [String] username
    # @param password [String] password
    # @raise [AuthError] if user session could not be created
    def login(username, password)
      r = self.Links.Sessions.post(
        payload: { "UserName" => username, "Password" => password }
      )
      raise AuthError unless r.status == 201

      logout
      rdata = r.data
      @connector.add_headers(AUTH_HEADER => rdata[:headers][AUTH_HEADER])
      @session = Resource.new(@connector, content: JSON.parse(rdata[:body]))
    end

    # Sign out of the service.
    #
    # If the session could not be deleted, {AuthError} will be raised.
    def logout
      return unless @session
      r = @session.delete
      raise AuthError unless r.status == 204
      @session = nil
      @connector.remove_headers([AUTH_HEADER])
    end
  end
end
