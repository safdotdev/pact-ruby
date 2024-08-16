require 'pact/consumer'
require 'pact/consumer/spec_hooks_ffi'
require 'pact/consumer/consumer_contract_builders_ffi'
require 'pact/rspec'
require 'pact/helpers'

module Pact
  module Consumer
    module RSpec
      module Ffi
        include Pact::Consumer::Ffi::ConsumerContractBuilders
        include Pact::Helpers
      end
    end
  end
end

hooks = Pact::Consumer::Ffi::SpecHooks.new

RSpec.configure do |config|
  config.include Pact::Consumer::RSpec::Ffi, :pact => true

  config.before :all, :pact => true do
    hooks.before_all
  end

  config.before :each, :pact => true do | example |
    hooks.before_each Pact::RSpec.full_description(example)
  end

  config.after :each, :pact => true do | example |
    hooks.after_each Pact::RSpec.full_description(example)
  end

  config.after :suite do
    hooks.after_suite
  end
end
