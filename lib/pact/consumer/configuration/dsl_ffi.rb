require 'pact/consumer/configuration/service_consumer'

module Pact
  module Consumer
    module Ffi
      module DSL
        def service_consumer_ffi name, &block
          Configuration::Ffi::ServiceConsumer.build(name, &block)
        end
      end
    end
  end
end