# frozen_string_literal: true

require "excon"
require "redfish_client/root"

RSpec.describe RedfishClient::Root do
  before(:all) do
    Excon.defaults[:mock] = true
    Excon.stub(
      { path: "/" },
      { status: 200,
        body: {
          "Links" => { "Sessions" => { "@odata.id" => "/sess" } },
          "Auth" => { "@odata.id" => "/auth" }
        }.to_json }
    )
    Excon.stub(
      { path: "/sess",
        method: :get },
      { status: 200,
        body: { "@odata.id": "/sess" }.to_json }
    )
    Excon.stub(
      { path: "/sess",
        method: :post,
        body: { "UserName" => "user", "Password" => "pass" }.to_json },
      { status: 201,
        body: { "@odata.id": "/sess/1" }.to_json,
        headers: { "X-Auth-Token" => "token" } }
    )
    Excon.stub(
      { path: "/sess/1", method: :delete },
      { status: 204 }
    )
    Excon.stub(
      { path: "/auth", headers: { "X-Auth-Token" => "token" } },
      { status: 200, body: { "key" => "val" }.to_json }
    )
  end

  after(:all) do
    Excon.stubs.clear
  end

  let(:connector) { RedfishClient::Connector.new("http://example.com") }
  subject { described_class.new(connector, oid: "/") }

  context "#login" do
    it "authenticates user against service" do
      subject.login("user", "pass")
      expect(subject.Auth.key).to eq("val")
    end
  end

  context "#logout" do
    it "terminates user session" do
      subject.login("user", "pass")
      subject.logout
      expect { subject.Auth }.to raise_error(Excon::Error::StubNotFound)
    end
  end
end
