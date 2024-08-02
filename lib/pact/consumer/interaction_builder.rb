require 'net/http'
require 'pact/reification'
require 'pact/consumer_contract/interaction'

module Pact
  module Consumer
    class InteractionBuilder

      attr_reader :interaction
      attr_accessor :pact

      def initialize(pact, &block)
        @interaction = Interaction.new
        @pact = pact
        @callback = block
      end

      def without_writing_to_pact
        interaction.metadata ||= {}
        interaction.metadata[:write_to_pact] = false
        self
      end

      def upon_receiving(description)
        if @interaction_ffi.nil?
          @interaction_ffi = PactFfi::HttpConsumer.new_interaction(@pact, description)
        else
          PactFfi.upon_receiving(@interaction_ffi, description)
        end
        @interaction.description = description
        self
      end

      def given(provider_state)
        @interaction_ffi = PactFfi::HttpConsumer.new_interaction(@pact, '') if @interaction_ffi.nil?
        PactFfi::HttpConsumer.given(@interaction_ffi, provider_state.to_s) if provider_state
        @interaction.provider_state = provider_state.nil? ? nil : provider_state.to_s
        self
      end

      def with(request_details)
        if request_details[:method] && request_details[:path]
          PactFfi::HttpConsumer.with_request(@interaction_ffi, request_details[:method].to_s,
                                             request_details[:path].to_s)
        end
        interaction.request = Pact::Request::Expected.from_hash(request_details)
        request_details[:headers]&.each_with_index do |h, _i|
          key = h[0]
          value = h[1].to_json
          PactFfi::HttpConsumer.with_header_v2(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
                                               key, 0, value)
        end
        if request_details[:body]
          PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
                                          nil, JSON.dump(request_details[:body]))
        end
        self
      end

      def will_respond_with(response)
        response[:headers]&.each_with_index do |h, i|
          key = h[0]
          value = h[1].to_json
          PactFfi::HttpConsumer.with_header_v2(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_RESPONSE'],
                                               key, i, value)
        end
        if response[:body]
          PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_RESPONSE'],
                                          nil, JSON.dump(response[:body]))
        end
        PactFfi::HttpConsumer.response_status(@interaction_ffi, response[:status]) if response[:status]
        interaction.response = Pact::Response.new(response)
        @callback.call interaction
        self
      end

    end
  end
end
