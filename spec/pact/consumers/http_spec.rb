# frozen_string_literal: true

require "sbmt/pact/rspec"

RSpec.describe "Sbmt::Pact::Consumers::Http", :pact_v2 do
  http_pact_provider "sbmt-pact-test-app"
end
