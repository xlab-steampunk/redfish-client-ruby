# frozen_string_literal: true

require "redfish_client/nil_hash"

def random_string
  ("a".."z").to_a.shuffle[0, rand(0...20)].join
end

RSpec.describe RedfishClient::NilHash do
  subject(:hash) { described_class.new }

  context "#[]" do
    5.times do
      key = random_string
      it "returns nil on #{key}" do
        expect(hash[key]).to be_nil
      end
    end
  end

  context "#[]=" do
    5.times do
      key = random_string
      value = random_string
      it "returns #{value} on #{key} assignment" do
        ret = hash[key] = value
        expect(ret).to eq(value)
        expect(hash[key]).to be_nil
      end
    end
  end

  context "#clear" do
    it "does not fail" do
      expect { hash.clear }.not_to raise_error
    end
  end

  context "#delete" do
    5.times do
      key = random_string
      it "does not fail with #{key}" do
        expect { hash.clear }.not_to raise_error
      end
    end
  end
end
