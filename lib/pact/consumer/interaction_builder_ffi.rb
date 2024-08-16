require 'net/http'
require 'pact/reification'
require 'pact/consumer_contract/interaction'

module Pact
  module Consumer
    module Ffi
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
          if request_details[:query]
            puts request_details[:query]
            puts request_details[:query].class
            query_params = CGI.parse(request_details[:query])
            puts query_params
            # request_details[:query] = Hash[query_params.map { |k, v| [k.split('=').first, v.split('=').last] }]
            # puts request_details[:query]
            query_params.each do |k, v|
              if v.nil? || v.empty?
                v = k.to_s.split('=').last
                k = k.to_s.split('=').first
              end
              key = k
              val = v.to_json
              if v.instance_of?(Array)
                array = JSON.parse(val.to_s)
                array.each_with_index do |vv, i|
                  vv = vv.to_json if vv.is_a?(Hash)
                  PactFfi.with_query_parameter_v2(@interaction_ffi, key.to_s, i, vv)
                end
              else
                PactFfi.with_query_parameter_v2(@interaction_ffi, key.to_s, 0, JSON.parse(val))
              end
            end
          end

          if request_details[:method] && request_details[:path]
            PactFfi::HttpConsumer.with_request(@interaction_ffi, request_details[:method].to_s,
                                              JSON.parse(request_details[:path].to_json))
          end
          interaction.request = Pact::Request::Expected.from_hash(request_details)
          request_details[:headers]&.each_with_index do |h, _i|
            key = h[0]
            value = h[1]
            if value.is_a?(Pact::Term) || value.is_a?(Pact::SomethingLike) || value.is_a?(ArrayLike) || value.instance_of?(Regexp)
              value = value.to_json
            end
            PactFfi::HttpConsumer.with_header(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
                                              key.to_s, 0, JSON.parse(value.to_json))
          end
          # if request_details[:body]
          #   PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
          #                                   nil, request_details[:body].to_json)
          # end

          if request_details[:body]
            value = request_details[:body]
            value_as_json = value.to_json
            puts "REQUEST #{value} type: #{value.class} value_as_json: #{value_as_json} "

            content_type = request_details[:headers]&.fetch('Content-Type', nil)
            # PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
            #                                 content_type, JSON.parse(value_as_json.to_json))
            if value.is_a?(Pact::Term) || value.is_a?(Pact::SomethingLike) || value.is_a?(ArrayLike) || value.instance_of?(Regexp)
              # if we pass a json body directly to with_body, it assumes content/type is application/json, even if we want text/plain
              # pass in the matching rules seperately to correct
              # and pass only the value into with_body
              matching_rules = value.to_json
              puts "matching_rules before #{matching_rules}"
              puts "matching_rules modder #{matching_rules}"
              if matching_rules['value'].nil?
                parsed_matching_rules = JSON.parse(matching_rules)
                matching_rules = JSON.dump({ 'pact:matcher:type' => 'regex', 'value' => parsed_matching_rules['s'],
                                            'regex' => parsed_matching_rules['s'] })
              end
              puts "matching_rules after #{matching_rules}"
              PactFfi.with_matching_rules(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
                                          matching_rules)
              PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
                                              JSON.parse(content_type.to_json), JSON.parse(matching_rules)['value'])

            else
              value = if value.instance_of?(Array) || value.instance_of?(Hash) || value.instance_of?(String)
                        value.to_json
                      else
                        value.to_s
                      end
              content_type = JSON.parse(content_type.to_json)['value'] if content_type.instance_of?(Pact::Term)
              PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_REQUEST'],
                                              content_type, value)
            end
          end
          self
        end

        def will_respond_with(response)
          interaction.response = Pact::Response.new(response)

          response[:headers]&.each_with_index do |h, _i|
            key = h[0]
            value = h[1]
            if value.is_a?(Pact::Term) || value.is_a?(Pact::SomethingLike) || value.is_a?(ArrayLike) || value.include?('Regexp')
              value = value.to_json
            end
            PactFfi::HttpConsumer.with_header_v2(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_RESPONSE'],
                                                key, 0, value)
          end
          PactFfi::HttpConsumer.response_status(@interaction_ffi, response[:status]) if response[:status]
          if response[:body]
            value = interaction.response.body
            value_as_json = value.to_json
            puts "RESPONSE #{value} class:  #{value.class} value_as_json: #{value_as_json} "
            content_type = interaction&.response&.headers&.fetch('Content-Type', nil)
            # PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_RESPONSE'],
            #                                 content_type, JSON.parse(value_as_json.to_json))

            if value.is_a?(Pact::Term) || value.is_a?(Pact::SomethingLike) || value.is_a?(ArrayLike) || value.instance_of?(Regexp)
              # if we pass a json body directly to with_body, it assumes content/type is application/json, even if we want text/plain
              # pass in the matching rules seperately to correct
              # and pass only the value into with_body
              matching_rules = value.to_json
              if matching_rules['value'].nil?
                parsed_matching_rules = JSON.parse(matching_rules)
                matching_rules = JSON.dump({ 'pact:matcher:type' => 'regex', 'value' => parsed_matching_rules['s'],
                                            'regex' => parsed_matching_rules['s'] })
              end
              PactFfi.with_matching_rules(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_RESPONSE'],
                                          JSON.parse(matching_rules.to_json))
              PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_RESPONSE'],
                                              content_type, JSON.parse(matching_rules)['value'])
            else
              value = interaction.response.body
              value = if value.instance_of?(Array) || value.instance_of?(Hash)
                        value.to_json
                      else
                        value.to_s
                      end
              PactFfi::HttpConsumer.with_body(@interaction_ffi, PactFfi::FfiInteractionPart['INTERACTION_PART_RESPONSE'],
                                              nil, value)
            end
          end
          @callback.call interaction
          self
        end
      end
    end
  end
end