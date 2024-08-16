require 'pact/configuration'
require 'pact/consumer/consumer_contract_builders'
require 'pact/consumer/consumer_contract_builder'
require 'pact/consumer/consumer_contract_builders_ffi'
require 'pact/consumer/consumer_contract_builder_ffi'
require 'pact/consumer/configuration/service_consumer'
require 'pact/consumer/configuration/service_consumer_ffi'
require 'pact/consumer/configuration/service_provider'
require 'pact/consumer/configuration/service_provider_ffi'
require 'pact/consumer/configuration/dsl'
require 'pact/consumer/configuration/dsl_ffi'
require 'pact/consumer/configuration/configuration_extensions'

Pact.send(:extend, Pact::Consumer::DSL)
Pact.send(:extend, Pact::Consumer::Ffi::DSL)
Pact::Configuration.send(:include, Pact::Consumer::Configuration::ConfigurationExtensions)