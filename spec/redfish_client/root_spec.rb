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
    Excon.stub(
      { path: "/basic_root" },
      { status: 200, body: { "res" => { "@odata.id" => "/basic" } }.to_json }
    )
    Excon.stub(
      { path: "/basic" },
      { status: 401, body: { "error" => "no auth" }.to_json }
    )
    Excon.stub(
      { path: "/basic", headers: { "Authorization" => "Basic dXNlcjpwYXNz" } },
      { status: 200, body: { "key" => "basic_val" }.to_json }
    )
    Excon.stub(
      { path: "/find" },
      { status: 200, body: { "find" => "resource" }.to_json }
    )
  end

  after(:all) do
    Excon.stubs.clear
  end

  context "with sessions" do
    let(:connector) { RedfishClient::Connector.new("http://example.com") }
    subject { described_class.new(connector, oid: "/") }
    before { subject.login("user", "pass") }

    context "#login" do
      it "authenticates user against service" do
        expect(subject.Auth.key).to eq("val")
      end
    end

    context "#logout" do
      it "terminates user session" do
        subject.logout
        expect { subject.Auth }.to raise_error(Excon::Error::StubNotFound)
      end
    end
  end

  context "without sessions" do
    let(:connector) { RedfishClient::Connector.new("http://example.com") }
    subject { described_class.new(connector, oid: "/basic_root") }
    before { subject.login("user", "pass") }

    context "#login" do
      it "authenticates user against service" do
        expect(subject.res.key).to eq("basic_val")
      end
    end

    context "#logout" do
      it "terminates user session" do
        subject.logout
        expect(subject.res.error).to eq("no auth")
      end
    end
  end

  let(:connector) { RedfishClient::Connector.new("http://example.com") }
  subject { described_class.new(connector, oid: "/") }

  context "#find" do
    it "fetches resource by OData id" do
      res = subject.find("/find")
      expect(res.raw).to eq("find" => "resource", "@odata.id" => "/find")
    end
  end
end
