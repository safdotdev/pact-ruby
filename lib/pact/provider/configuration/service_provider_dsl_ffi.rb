require 'pact/provider/configuration/pact_verification'
require 'pact/provider/configuration/pact_verification_from_broker'
require 'pact/provider/configuration/service_provider_config_ffi'
require 'pact/errors'

module Pact

  module Provider

    module Configuration
      module Ffi
        class Error < ::Pact::Error; end

        class ServiceProviderDSL

          extend Pact::DSL

          attr_accessor :name, :app_block, :application_version, :branch, :tags, :publish_verification_results,
                        :build_url, :provider_base_url

          CONFIG_RU_APP = lambda {
            unless File.exist? Pact.configuration.config_ru_path
              raise "Could not find config.ru file at #{Pact.configuration.config_ru_path} Please configure the service provider app or create a config.ru file in the root directory of the project. See https://github.com/pact-foundation/pact-ruby/wiki/Verifying-pacts for more information."
            end
            result = Rack::Builder.parse_file(Pact.configuration.config_ru_path)

            if result.respond_to?(:first) # rack 2
              result.first
            else # rack 3
              result
            end
          }

          def initialize name
            @name = name
            @publish_verification_results = false
            @provider_base_url = provider_base_url
            @tags = []
            @app_block = CONFIG_RU_APP
          end

          dsl do
            def app &block
              self.app_block = block
            end

            def app_version application_version
              self.application_version = application_version
            end

            def app_version_tags tags
              self.tags = tags
            end

            def app_version_branch branch
              self.branch = branch
            end

            def build_url build_url
              self.build_url = build_url
            end

            def provider_base_url(provider_base_url)
              self.provider_base_url = provider_base_url
            end

            def publish_verification_results publish_verification_results
              self.publish_verification_results = publish_verification_results
              Pact::RSpec.with_rspec_2 do
                Pact.configuration.error_stream.puts "WARN: Publishing of verification results is currently not supported with rspec 2. If you would like this functionality, please feel free to submit a PR!"
              end
            end

            def honours_pact_with consumer_name, options = {}, &block
              create_pact_verification consumer_name, options, &block
            end

            def honours_pacts_from_pact_broker &block
              create_pact_verification_from_broker(&block)
            end
          end

          def create_pact_verification consumer_name, options, &block
            PactVerification.build(consumer_name, options, &block)
          end

          def create_pact_verification_from_broker(&block)
            PactVerificationFromBroker.build(name, branch, tags, &block)
          end

          def finalize
            validate
            create_service_provider
          end

          private

          def validate
            raise Error.new("Please provide a name for the Provider") unless name && !name.strip.empty?
            raise Error.new("Please set the app_version when publish_verification_results is true") if publish_verification_results && application_version_blank?
            raise Error.new('Please set the provider_base_url') if provider_base_url_blank? && self.class == instance_of?(MessageProviderDSL)
          end

          def application_version_blank?
            application_version.nil? || application_version.strip.empty?
          end
          def provider_base_url_blank?
            provider_base_url.nil? || provider_base_url.strip.empty?
          end

          def create_service_provider
            Pact.configuration.provider = Pact::Provider::Configuration::Ffi::ServiceProviderConfig.new(application_version, branch, tags,
                                                                    publish_verification_results, build_url, provider_base_url, &@app_block)
          end
        end
      end
    end
  end
end