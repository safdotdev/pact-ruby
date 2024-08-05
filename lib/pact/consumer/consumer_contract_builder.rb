require 'uri'
require 'json/add/regexp'
require 'pact/logging'
# require 'pact/mock_service/client'
require 'pact/consumer/interaction_builder'
require 'pact/ffi'
require 'pact/ffi/logger'
require 'pact/ffi/http_consumer'
require 'pact/ffi/mock_server'
require 'pact/errors'

module Pact
  module Consumer

    class ConsumerContractBuilder

      include Pact::Logging

      attr_reader :consumer_contract, :mock_service_base_url, :port

      def initialize(attributes)
        @interaction_builder = nil
        @consumer_contract_details = {
          consumer: { name: attributes[:consumer_name] },
          provider: { name: attributes[:provider_name] },
          pactfile_write_mode: attributes[:pactfile_write_mode].to_s,
          pact_dir: attributes.fetch(:pact_dir)
        }
        # @mock_service_client = Pact::MockService::Client.new(attributes[:port], attributes[:host])
        PactFfi::Logger.log_to_stdout(3)
        @port = attributes[:port] ||= 0
        @mock_service_base_url = "http://#{attributes[:host]}:#{@port}"
        @mock_server_host = attributes[:host]
        @pact = PactFfi.new_pact(@consumer_contract_details[:consumer][:name],
                                 @consumer_contract_details[:provider][:name])
        PactFfi::HttpConsumer.with_specification(@pact, PactFfi::FfiSpecificationVersion['SPECIFICATION_VERSION_V2'])
      end

      def without_writing_to_pact
        interaction_builder.without_writing_to_pact
      end

      def given(provider_state)
        interaction_builder.given(provider_state)
      end

      def upon_receiving(description)
        interaction_builder.upon_receiving(description)
      end

      def verify
        matched = PactFfi::MockServer.matched(@port)
        puts matched
        return unless matched != true

        mismatches = PactFfi::MockServer.mismatches(@port)
        if mismatches
          validation_errors = JSON.pretty_generate(JSON.load(mismatches))
        else
          validation_errors = 'do not match'
        end
        PactFfi::MockServer.cleanup(@port)
        raise validation_errors
      end

      def log(msg)
        # mock_service_client.log msg
      end

      def start_mock
        @port = PactFfi::MockServer.create_for_transport(@pact, @mock_server_host, @port,
                                                         'http', nil)
      end

      def write_pact
        if @port
          result = PactFfi::MockServer.write_pact_file(@port, @consumer_contract_details[:pact_dir], true)

          pact_file_path = File.join(@consumer_contract_details[:pact_dir], "#{@consumer_contract_details[:consumer][:name]}-#{@consumer_contract_details[:provider][:name]}.json")
          pact_file_contents = File.read(pact_file_path)
          # puts pact_file_contents
          if result != 0
            case result
            when 1
              puts "Error: A general panic was caught"
            when 2
              puts "Error: The pact file was not able to be written"
            when 3
              puts "Error: A mock server with the provided port #{@port} was not found"
            end
          end
          pact_file_contents
        else
          puts 'rust mock server is not running'
        end
      end

      def cleanup
        PactFfi::MockServer.cleanup(@port)
      end

      def wait_for_interactions options = {}
        wait_max_seconds = options.fetch(:wait_max_seconds, 3)
        poll_interval = options.fetch(:poll_interval, 0.1)
      end

      # @raise Pact::InvalidInteractionError
      def handle_interaction_fully_defined interaction
        interaction.validate!
        self.interaction_builder = nil
      end

      private

      attr_writer :interaction_builder

      def interaction_builder
        @interaction_builder ||=
        begin
          interaction_builder = InteractionBuilder.new(@pact) do |interaction|
            handle_interaction_fully_defined(interaction)
          end
          interaction_builder
        end
      end

    end
  end
end
