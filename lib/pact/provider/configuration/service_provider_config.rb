module Pact
  module Provider
    module Configuration
      class ServiceProviderConfig

        attr_accessor :application_version, :provider_base_url
        attr_reader :branch, :build_url

        def initialize application_version, branch, tags, publish_verification_results, build_url, provider_base_url, &app_block
          @application_version = application_version
          @branch = branch
          @tags = [*tags]
          @publish_verification_results = publish_verification_results
          @app_block = app_block
          @build_url = build_url
          @provider_base_url = provider_base_url
        end

        def app
          @app_block.call
        end

        def publish_verification_results?
          @publish_verification_results
        end

        def tags
          @tags
        end
      end
    end
  end
end