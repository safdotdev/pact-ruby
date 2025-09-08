
if ENV['PACT_RUBY_V2_ENABLE'] == 'true'
  require 'pact/v2'
end
if ENV['PACT_RUBY_V1_ENABLE'] != 'false'
  require 'pact/support'
  require 'pact/version'
  require 'pact/configuration'
  require 'pact/consumer'
  require 'pact/provider'
  require 'pact/consumer_contract'
end