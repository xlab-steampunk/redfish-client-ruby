# frozen_string_literal: true

require "base64"
require "json"
require "redfish_client/resource"

module RedfishClient
  # Root resource represents toplevel entry point into Redfish service data.
  # Its main purpose is to provide authentication support for the API.
  class Root < Resource
    # AuthError is raised if the user session cannot be created.
    class AuthError < StandardError; end

    # Basic and token authentication headers.
    BASIC_AUTH_HEADER = "Authorization"
    TOKEN_AUTH_HEADER = "X-Auth-Token"

    # Authenticate against the service.
    #
    # Calling this method will try to create new session on the service using
    # provided credentials. If the session creation fails, basic
    # authentication will be attempted. If basic authentication fails,
    # {AuthError} will be raised.
    #
    # @param username [String] username
    # @param password [String] password
    # @raise [AuthError] if user session could not be created
    def login(username, password)
      # Since session auth is more secure, we try it first and use basic auth
      # only if session auth is not available.
      if session_login_available?
        session_login(username, password)
      else
        basic_login(username, password)
      end
    end

    # Sign out of the service.
    #
    # If the session could not be deleted, {AuthError} will be raised.
    def logout
      session_logout
      basic_logout
    end

    # Find Redfish service object by OData ID field.
    #
    # @param oid [String] Odata id of the resource
    # @return [Resource] new resource
    def find(oid)
      Resource.new(@connector, oid: oid)
    end

    private

    def session_login_available?
      !@content.dig("Links", "Sessions").nil?
    end

    def session_login(username, password)
      r = @connector.post(
        @content["Links"]["Sessions"]["@odata.id"],
        "UserName" => username, "Password" => password
      )
      raise AuthError, "Invalid credentials" unless r.status == 201

      session_logout

      payload = r.data[:headers][TOKEN_AUTH_HEADER]
      @connector.add_headers(TOKEN_AUTH_HEADER => payload)
      @session = Resource.new(@connector, content: JSON.parse(r.data[:body]))
    end

    def session_logout
      return unless @session
      r = @session.delete
      raise AuthError unless r.status == 204
      @session = nil
      @connector.remove_headers([TOKEN_AUTH_HEADER])
    end

    def auth_test_path
      @content.values.map { |v| v["@odata.id"] }.compact.first
    end

    def basic_login(username, password)
      payload = Base64.encode64("#{username}:#{password}").strip
      @connector.add_headers(BASIC_AUTH_HEADER => "Basic #{payload}")
      r = @connector.get(auth_test_path)
      raise AuthError, "Invalid credentials" unless r.status == 200
    end

    def basic_logout
      @connector.remove_headers([BASIC_AUTH_HEADER])
    end
  end
end
