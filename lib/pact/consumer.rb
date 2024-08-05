require 'pact/consumer_contract'
require 'pact/consumer/configuration'
require 'pact/consumer/consumer_contract_builder'
require 'pact/consumer/consumer_contract_builders'
require 'pact/consumer/interaction_builder'
require 'pact/term'
require 'pact/something_like'
# why does this need hoisting? as it is also here lib/pact.rb
# when testing pact-ruby-e2e-example
require 'pact/support'
