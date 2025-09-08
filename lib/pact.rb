
if ENV['PACT_RUBY_V2_ENABLE'] == 'true'
  require 'pact/v2'
else
  require 'pact/support'
  require 'pact/version'
  require 'pact/configuration'
  require 'pact/consumer'
  require 'pact/provider'
  require 'pact/consumer_contract'
end