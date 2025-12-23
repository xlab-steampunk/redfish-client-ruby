# frozen_string_literal: true

require "base64"
require "excon"
require "json"
require "logger"

require "redfish_client/nil_hash"
require "redfish_client/response"

module RedfishClient
  # Connector serves as a low-level wrapper around HTTP calls that are used
  # to retrieve data from the service API. It abstracts away implementation
  # details such as sending the proper headers in request, which do not
  # change between resource fetches.
  #
  # Library users should treat this class as an implementation detail and
  # use higer-level {RedfishClient::Resource} instead.
  class Connector
    # AuthError is raised if the credentials are invalid.
    class AuthError < StandardError; end

    # Default headers, as required by Redfish spec
    # https://redfish.dmtf.org/schemas/DSP0266_1.4.0.html#request-headers
    DEFAULT_HEADERS = {
      "Accept" => "application/json",
      "OData-Version" => "4.0",
    }.freeze

    # Basic and token authentication header names
    BASIC_AUTH_HEADER = "Authorization"
    TOKEN_AUTH_HEADER = "X-Auth-Token"
    LOCATION_HEADER   = "Location"

    # Create new connector.
    #
    # By default, connector performs no caching. If caching is desired,
    # Hash should be used as a cache implementation.
    #
    # It is also possible to pass in custom caching class. Instances of that
    # class should respond to the following four methods:
    #
    #  1. `[](key)`         - Used to access cached content and should return
    #                         `nil` if the key has no associated value.
    #  2. `[]=(key, value)` - Cache `value` under the `key`
    #  3. `clear`           - Clear the complete cache.
    #  4. `delete(key)`     - Invalidate cache entry associated with `key`.
    #
    # @param url [String] base url of the Redfish service
    # @param verify [Boolean] verify SSL certificate of the service
    # @param use_session [Boolean] Use a session for authentication
    # @param cache [Object] cache backend
    def initialize(url, verify: true, cache: nil, use_session: true)
      @url = url
      @headers = DEFAULT_HEADERS.dup
      middlewares = Excon.defaults[:middlewares] +
        [Excon::Middleware::RedirectFollower]
      @connection = Excon.new(@url,
                              ssl_verify_peer: verify,
                              middlewares: middlewares)
      @cache = cache || NilHash.new
      @use_session = use_session
    end

    # Add HTTP headers to the requests made by the connector.
    #
    # @param headers [Hash<String, String>] headers to be added
    def add_headers(headers)
      @headers.merge!(headers)
    end

    # Remove HTTP headers from requests made by the connector.
    #
    # Headers that are not currently set are silently ignored and no error is
    # raised.
    #
    # @param headers [List<String>] headers to remove
    def remove_headers(headers)
      headers.each { |h| @headers.delete(h) }
    end

    # Issue requests to the service.
    #
    # @param mathod [Symbol] HTTP method (:get, :post, :patch or :delete)
    # @param path [String] path to the resource, relative to the base
    # @param data [Hash] data to be sent over the socket
    # @return [Response] response object
    def request(method, path, data = nil)
      return @cache[path] if method == :get && @cache[path]

      do_request(method, path, data).tap do |r|
        @cache[path] = r if method == :get && r.status == 200
      end
    end

    # Issue GET request to service.
    #
    # This method will first try to return cached response if available. If
    # cache does not contain entry for this request, data will be fetched from
    # remote and then cached, but only if the response has an OK (200) status.
    #
    # @param path [String] path to the resource, relative to the base url
    # @return [Response] response object
    def get(path)
      request(:get, path)
    end

    # Issue POST requests to the service.
    #
    # @param path [String] path to the resource, relative to the base
    # @param data [Hash] data to be sent over the socket, JSON encoded
    # @return [Response] response object
    def post(path, data = nil)
      request(:post, path, data)
    end

    # Issue PATCH requests to the service with optional ETag support.
    #
    # @param path [String] path to the resource, relative to the base
    # @param data [Hash] data to be sent over the socket
    # @param options [Hash] optional parameters including :etag
    # @return [Response] response object
    def patch(path, data = nil, **options)
      etag_handler(path, data, options[:etag])
    end

    # Issue DELETE requests to the service.
    #
    # @param path [String] path to the resource, relative to the base
    # @return [Response] response object
    def delete(path)
      request(:delete, path)
    end

    # Clear the cached responses.
    #
    # If path is passed as a parameter, only one cache entry gets invalidated,
    # else complete cache gets invalidated.
    #
    # Next GET request will repopulate the cache.
    #
    # @param path [String] path to invalidate
    def reset(path = nil)
      path.nil? ? @cache.clear : @cache.delete(path)
    end

    # Set authentication-related variables.
    #
    # Last parameter controls the kind of login connector will perform. If
    # session_path is `nil`, basic authentication will be used, otherwise
    # connector will use session-based authentication.
    #
    # Note that actual login is done lazily. If you need to check for
    # credential validity, call #{login} method.
    #
    # @param username [String] API username
    # @param password [String] API password
    # @param auth_test_path [String] API path to test credential's validity
    # @param session_path [String, nil] API session path
    def set_auth_info(username, password, auth_test_path, session_path = nil)
      @username = username
      @password = password
      @auth_test_path = auth_test_path
      @session_path = @use_session ? session_path : nil
    end

    # Authenticate against the service.
    #
    # Calling this method will try to authenticate against API using
    # credentials provided by #{set_auth_info} call.
    # If authentication fails, # {AuthError} will be raised.
    #
    # @raise [AuthError] if credentials are invalid
    def login
      @session_path ? session_login : basic_login
    end

    # Sign out of the service.
    def logout
      # We bypass request here because we do not want any retries on 401
      # when doing logout.
      if @session_oid
        params = prepare_request_params(:delete, @session_oid)
        @connection.request(params)
        @session_oid = nil
      end
      remove_headers([BASIC_AUTH_HEADER, TOKEN_AUTH_HEADER])
    end

    private

    # ETag handler containing workarounds for PATCH requests with ETags.
    # Based on sushy's _etag_handler implementation.
    #
    # @param path [String] path to the resource
    # @param data [Hash] data to be sent
    # @param etag [String, nil] ETag value
    # @return [Response] response object
    def etag_handler(path, data, etag)
      # Guard clause: if no ETag provided, perform regular PATCH and return
      return request(:patch, path, data) if etag.nil? || etag.empty?

      logger = Logger.new($stdout)
      logger.level = Logger::WARN

      # Prepare headers with If-Match
      headers_to_add = { "If-Match" => etag }
      add_headers(headers_to_add)

      begin
        # First attempt with the provided ETag
        response = request(:patch, path, data)

        # Handle 412 Precondition Failed with retry logic.
        # Some hardware vendors have non-standard Redfish implementations
        # that incorrectly handle ETags (e.g., rejecting weak ETags or
        # requiring ETags to be omitted even when provided correctly).
        # To work around these vendor-specific issues, we retry with:
        # 1. Converting weak ETag (W/"...") to strong ETag ("...")
        # 2. Removing the If-Match header entirely
        # This approach is based on similar workarounds implemented in
        # the Sushy library:
        # https://github.com/openstack/sushy
        # Other statuses (success or errors like 400, 500) should be
        # returned as-is for the caller to handle appropriately.
        unless response.status == 412
          return response
        end

        logger.warn("Initial request with eTag failed: HTTP 412")

        # Check for weak ETag (W/"...")
        weak_etag_pattern = /^(W\/)(".+")$/
        match = weak_etag_pattern.match(etag)

        if match
          logger.info("Weak eTag provided with original request to #{path}. " \
                     "Attempting conversion to strong eTag and re-trying.")

          # Try with strong ETag (remove W/ prefix)
          strong_etag = match[2]
          remove_headers(["If-Match"])
          add_headers("If-Match" => strong_etag)

          response = request(:patch, path, data)

          unless response.status == 412
            return response
          end

          logger.warn("Request to #{path} with weak eTag converted to " \
                     "strong eTag also failed. Making the final attempt " \
                     "with no eTag specified.")
        else
          # ETag is strong, retry without it
          logger.warn("Strong eTag provided - retrying request to #{path} " \
                     "with eTag removed.")
        end

        # Final attempt without If-Match header
        remove_headers(["If-Match"])
        response = request(:patch, path, data)

        if response.status == 412
          logger.error("Final re-try with eTag removed has also failed with HTTP 412")
        end

        response
      ensure
        # Clean up headers
        remove_headers(headers_to_add.keys) unless headers_to_add.empty?
      end
    end

    def do_request(method, path, data)
      params = prepare_request_params(method, path, data)
      r = @connection.request(params)
      if r.status == 401
        login
        r = @connection.request(params)
      end
      Response.new(r.status, downcase_headers(r.data[:headers]), r.data[:body])
    end

    def downcase_headers(headers)
      headers.each_with_object({}) { |(k, v), obj| obj[k.downcase] = v }
    end

    def prepare_request_params(method, path, data = nil)
      params = { method: method, path: path }
      if data
        params[:body] = data.to_json
        params[:headers] = @headers.merge("Content-Type" => "application/json")
      else
        params[:headers] = @headers
      end
      params
    end

    def session_login
      # We bypass request here because we do not want any retries on 401
      # when doing login.
      params = prepare_request_params(:post, @session_path,
                                      "UserName" => @username,
                                      "Password" => @password)
      r = @connection.request(params)
      raise_invalid_auth_error unless r.status == 201

      body    = JSON.parse(r.data[:body])
      headers = r.data[:headers]

      add_headers(TOKEN_AUTH_HEADER => headers[TOKEN_AUTH_HEADER])
      save_session_oid!(body, headers)
    end

    def save_session_oid!(body, headers)
      @session_oid = body["@odata.id"] if body.key?("@odata.id")
      return if @session_oid

      return unless headers.key?(LOCATION_HEADER)

      location = URI.parse(headers[LOCATION_HEADER])
      @session_oid = [location.path, location.query].compact.join("?")
    end

    def basic_login
      payload = Base64.encode64("#{@username}:#{@password}").strip
      add_headers(BASIC_AUTH_HEADER => "Basic #{payload}")
      return if auth_valid?

      remove_headers([BASIC_AUTH_HEADER])
      raise_invalid_auth_error
    end

    def raise_invalid_auth_error
      raise AuthError, "Invalid credentials"
    end

    def auth_valid?
      # We bypass request here because we do not want any retries on 401
      # when checking authentication headers.
      reset(@auth_test_path) # Do not want to see cached response
      params = prepare_request_params(:get, @auth_test_path)
      @connection.request(params).status == 200
    end
  end
end
