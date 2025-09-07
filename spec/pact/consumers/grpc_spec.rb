# frozen_string_literal: true

require "sbmt/pact/rspec"

RSpec.describe "Sbmt::Pact::Consumers::Grpc", :pact_v2 do
  grpc_pact_provider "sbmt-pact-test-app"
end
