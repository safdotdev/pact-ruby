# frozen_string_literal: true

require "pact/v2/rspec"

RSpec.describe "Pact::V2::Consumers::Grpc", :pact_v2 do
  grpc_pact_provider "pact-ruby-v2-test-app"
end
