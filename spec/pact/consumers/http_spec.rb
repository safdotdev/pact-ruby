# frozen_string_literal: true

require "pact/v2/rspec"

RSpec.describe "Pact::V2::Consumers::Http", :pact_v2 do
  http_pact_provider "pact-ruby-v2-test-app"
end
