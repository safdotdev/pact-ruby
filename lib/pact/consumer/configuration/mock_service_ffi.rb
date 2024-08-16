require 'pact/consumer/consumer_contract_builder_ffi'
require 'pact/consumer/consumer_contract_builders_ffi'
require 'pact/consumer/world'

module Pact
  module Consumer
    module Configuration
      module Ffi
        class MockService

          extend Pact::DSL

          attr_accessor :port, :host, :standalone, :verify, :provider_name, :consumer_name,
                        :pact_specification_version

          def initialize name, consumer_name, provider_name
            @name = name
            @consumer_name = consumer_name
            @provider_name = provider_name
            @port = nil
            @host = "localhost"
            @standalone = false
            @verify = true
            @pact_specification_version = '2'
            @finalized = false
          end

          dsl do
            def port port
              self.port = port
            end

            def host host
              self.host = host
            end

            def standalone standalone
              self.standalone = standalone
            end

            def verify verify
              self.verify = verify
            end

            def pact_specification_version pact_specification_version
              self.pact_specification_version = pact_specification_version
            end
          end

          def finalize
            raise 'Already finalized!' if @finalized
            configure_consumer_contract_builder
            @finalized = true
          end

          private

          def configure_consumer_contract_builder
            consumer_contract_builder = create_consumer_contract_builder
            create_consumer_contract_builders_method consumer_contract_builder
            setup_verification(consumer_contract_builder) if verify
            consumer_contract_builder
          end

          def create_consumer_contract_builder
            consumer_contract_builder_fields = {
              :consumer_name => consumer_name,
              :provider_name => provider_name,
              :pactfile_write_mode => Pact.configuration.pactfile_write_mode,
              :port => port,
              :host => host,
              :pact_dir => Pact.configuration.pact_dir,
              :pact_specification_version => pact_specification_version
            }
            Pact::Consumer::Ffi::ConsumerContractBuilder.new consumer_contract_builder_fields
          end

          def setup_verification consumer_contract_builder
            Pact.configuration.add_provider_verification do | example_description |
              consumer_contract_builder.verify
            end
          end

          # This makes the consumer_contract_builder available via a module method with the given identifier
          # as the method name.
          # I feel this should be defined somewhere else, but I'm not sure where
          def create_consumer_contract_builders_method consumer_contract_builder_ffi
            Pact::Consumer::Ffi::ConsumerContractBuilders.send(:define_method, @name.to_sym) do
              consumer_contract_builder_ffi
            end
            Pact.consumer_world.add_consumer_contract_builder_ffi consumer_contract_builder_ffi
          end

          def mock_service_options
            {
              pact_specification_version: pact_specification_version,
              find_available_port: port.nil?,
            }
          end
        end
      end
    end
  end
end
