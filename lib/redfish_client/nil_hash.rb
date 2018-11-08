# frozen_string_literal: true

module RedfishClient
  # NilHash imitates the built-in Hash class without storing anything
  # permanently.
  #
  # Main use of this class is as a non-caching connector backend.
  class NilHash
    # Access hash member.
    #
    # Since this implementation does not store any data, return value is
    # always nil.
    #
    # @param _key not used
    # @return [nil]
    def [](_key)
      nil
    end

    # Set hash member.
    #
    # This is just a pass-through method, since it always simply returns the
    # value without actually storing it.
    #
    # @param _key not used
    # @param value [Object] any value
    # @return [Object] value
    def []=(_key, value)
      value
    end

    # Clear the contents of the cache.
    #
    # Since hash is not storing anything, this is a no-op.
    def clear; end

    # Delete entry from hash.
    #
    # Since hash is not storing anything, this is a no-op.
    #
    # @param _key not used
    def delete(_key) end
  end
end
