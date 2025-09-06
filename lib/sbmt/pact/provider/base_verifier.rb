# frozen_string_literal: true

require "pact/ffi/verifier"
require "sbmt/pact/native/logger"
require "sbmt/pact/native/blocking_verifier"

module Sbmt
  module Pact
    module Provider
      class BaseVerifier
        PROVIDER_TRANSPORT_TYPE = nil
        attr_reader :logger

        class VerificationError < Sbmt::Pact::FfiError; end

        class VerifierError < Sbmt::Pact::Error; end

        DEFAULT_CONSUMER_SELECTORS = {}

        # https://docs.rs/pact_ffi/0.4.17/pact_ffi/verifier/fn.pactffi_verify.html#errors
        VERIFICATION_ERRORS = {
          1 => {reason: :verification_failed, status: 1, description: "The verification process failed, see output for errors"},
          2 => {reason: :null_pointer, status: 2, description: "A null pointer was received"},
          3 => {reason: :internal_error, status: 3, description: "The method panicked"},
          4 => {reason: :invalid_arguments, status: 4, description: "Invalid arguments were provided to the verification process"}
        }.freeze

        # env below are set up by pipeline-builder
        # see paas/cicd/images/pact/pipeline-builder/-/blob/master/internal/commands/consumers-pipeline/ruby.go
        def initialize(pact_config)
          raise ArgumentError, "pact_config must be a subclass of Sbmt::Pact::Provider::PactConfig::Base" unless pact_config.is_a?(::Sbmt::Pact::Provider::PactConfig::Base)
          @pact_config = pact_config
          @logger = Logger.new($stdout)
        end

        def verify!
          raise VerifierError.new("interaction is designed to be used one-time only") if defined?(@used)

          # if consumer_selectors.blank?
          #   logger.info("[verifier] does not need to verify consumer #{@pact_config.consumer_name}")
          #   return
          # end

          exception = nil
          pact_handle = init_pact

          start_servers!

          logger.info("[verifier] starting provider verification")

          result = Sbmt::Pact::Native::BlockingVerifier.execute(pact_handle)
          if VERIFICATION_ERRORS[result].present?
            error = VERIFICATION_ERRORS[result]
            exception = VerificationError.new("There was an error while trying to verify provider \"#{@pact_config.provider_name}\"", error[:reason], error[:status])
          end
        ensure
          @used = true
          PactFfi::Verifier.shutdown(pact_handle) if pact_handle
          stop_servers

          raise exception if exception
        end

        private

        def create_c_pointer_array_from_string_array(string_array)
          pointers = string_array.map { |str| FFI::MemoryPointer.from_string(str) }
          array_pointer = FFI::MemoryPointer.new(:pointer, pointers.size)
          pointers.each_with_index do |ptr, index|
            array_pointer[index].put_pointer(0, ptr)
          end
          array_pointer
        end

        def bool_to_int(value)
          value ? 1 : 0
        end

        def init_pact
          handle = PactFfi::Verifier.new_for_application("sbmt-pact", PactFfi.version)
          set_provider_info(handle)
          PactFfi::Verifier.set_provider_state(handle, @pact_config.provider_setup_url, 1, 1)
          PactFfi::Verifier.set_verification_options(handle, 0, 10000)
          # pactffi_verifier_set_publish_options(
          #     handle: *mut VerifierHandle,
          #     provider_version: *const c_char,
          #     build_url: *const c_char,
          #     provider_tags: *const *const c_char,
          #     provider_tags_len: c_ushort,
          #     provider_branch: *const c_char,
          # )
          c_provider_version_tags = create_c_pointer_array_from_string_array(@pact_config.provider_version_tags)
          c_provider_version_tags_size = @pact_config.provider_version_tags.size
          c_consumer_version_tags = create_c_pointer_array_from_string_array(@pact_config.consumer_version_tags)
          c_consumer_version_tags_size = @pact_config.consumer_version_tags.size

          if @pact_config.provider_build_uri.present?
            begin
              URI.parse(@pact_config.provider_build_uri)
            rescue URI::InvalidURIError
              raise VerifierError.new("provider_build_uri is not a valid URI")
            end
          end

          if @pact_config.publish_verification_results == true
            if @pact_config.provider_version
              PactFfi::Verifier.set_publish_options(handle, @pact_config.provider_version, @pact_config.provider_build_uri, c_provider_version_tags, c_provider_version_tags_size, @pact_config.provider_version_branch)
            else
              logger.warn("[verifier] - unable to publish verification results as provider version is not set")
            end
          end

          configure_verification_source(handle, c_provider_version_tags, c_provider_version_tags_size, c_consumer_version_tags, c_consumer_version_tags_size)

          PactFfi::Verifier.set_no_pacts_is_error(handle, bool_to_int(@pact_config.fail_if_no_pacts_found))

          add_provider_transport(handle)

          # the core doesnt pick up these env vars, so we need to set them here
          # https://github.com/pact-foundation/pact-reference/issues/451#issuecomment-2338130587
          # PACT_DESCRIPTION
          # Only validate interactions whose descriptions match this filter (regex format)
          # PACT_PROVIDER_STATE
          # Only validate interactions whose provider states match this filter (regex format)
          # PACT_PROVIDER_NO_STATE
          # Only validate interactions that have no defined provider state (true or false)
          PactFfi::Verifier.set_filter_info(
            handle,
            ENV["PACT_DESCRIPTION"] || nil,
            ENV["PACT_PROVIDER_STATE"] || nil,
            bool_to_int(ENV["PACT_PROVIDER_NO_STATE"] || false)
          )

          # filters based on INTERACTION_FILTER_REGEX. e.g. "^grpc:.+", opinionated and v4 specific, so removed for now.
          ## set_filter_info(handle)
          # descriptions are set and read from parsed v4 spec pacts in a pact broker proxy

          #  excerpt from lib/sbmt/pact/provider/pact_broker_proxy.rb
          # pact_json_hash["interactions"].each do |interaction|
          #   set_description_prefix(interaction, "grpc:") if interaction["transport"] == "grpc" && filter_type == :grpc
          #   set_description_prefix(interaction, "http:") if interaction["transport"] == "http" && filter_type == :http
          #   set_description_prefix(interaction, "http:") if interaction["type"] == "Synchronous/HTTP" && filter_type == :http
          #   set_description_prefix(interaction, "async:") if interaction["type"] == "Asynchronous/Messages" && filter_type == :async
          #   set_description_prefix(interaction, "sync:") if interaction["type"] == "Synchronous/Messages" && filter_type == :sync
          # end

          Sbmt::Pact::Native::Logger.log_to_stdout(@pact_config.log_level)

          logger.info("[verifier] verification initialized for provider #{@pact_config.provider_name}, version #{@pact_config.provider_version}, transport #{self.class::PROVIDER_TRANSPORT_TYPE}")

          handle
        end

        def set_provider_info(pact_handle)
          #   pub extern "C" fn pactffi_verifier_set_provider_info(
          #     handle: *mut VerifierHandle,
          #     name: *const c_char,
          #     scheme: *const c_char,
          #     host: *const c_char,
          #     port: c_ushort,
          #     path: *const c_char,
          # ) {
          PactFfi::Verifier.set_provider_info(pact_handle, @pact_config.provider_name, "", "", 0, "")
        end

        def add_provider_transport(pact_handle)
          raise Sbmt::Pact::ImplementationRequired, "Implement #add_provider_transport in a subclass"
        end

        def set_filter_info(pact_handle)
          # e.g. PactFfi::Verifier.set_filter_info(pact_handle, "^grpc:.+", nil, 0)
          raise Sbmt::Pact::ImplementationRequired, "Implement #set_filter_info in a subclass"
        end

        def start_servers!
          logger.info("[verifier] starting services")

          @servers_started = true
          @pact_config.start_servers
        end

        def stop_servers
          return unless @servers_started

          logger.info("[verifier] stopping services")

          @pact_config.stop_servers
        end

        def configure_verification_source(handle, c_provider_version_tags, c_provider_version_tags_size, c_consumer_version_tags, c_consumer_version_tags_size)
          logger.info("[verifier] configuring verification source")
          if @pact_config.pact_broker_proxy_url.blank? && @pact_config.pact_uri.blank?
            # todo support non rail apps
            path = @pact_config.pact_dir || (defined?(Rails) ? Rails.root.join("pacts").to_s : "pacts")
            logger.info("[verifier] pact broker url or pact uri is not set, using directory #{path} as a verification source")
            return PactFfi::Verifier.add_directory_source(handle, path)
          end

          if @pact_config.pact_uri.present?
            if @pact_config.pact_uri.start_with?("http")
              logger.info("[verifier] using pact uri #{@pact_config.pact_uri} as a verification source")
              PactFfi::Verifier.url_source(handle, @pact_config.pact_uri, @pact_config.broker_username, @pact_config.broker_password, @pact_config.broker_token)
            else
              logger.info("[verifier] using pact file #{@pact_config.pact_uri} as a verification source")
              PactFfi::Verifier.add_file_source(handle, @pact_config.pact_uri)
            end
          else
            logger.info("[verifier] using pact broker url #{@pact_config.broker_url} with consumer selectors: #{JSON.dump(consumer_selectors)} as a verification source")
            consumer_selectors = [] if consumer_selectors.nil?
            filters = consumer_selectors.map do |selector|
              FFI::MemoryPointer.from_string(JSON.dump(selector).to_s)
            end
            filters_ptr = FFI::MemoryPointer.new(:pointer, filters.size + 1)
            filters_ptr.write_array_of_pointer(filters)
            PactFfi::Verifier.broker_source_with_selectors(handle, @pact_config.pact_broker_proxy_url, @pact_config.broker_username, @pact_config.broker_password, @pact_config.broker_token, bool_to_int(@pact_config.enable_pending), @pact_config.include_wip_pacts_since, c_provider_version_tags, c_provider_version_tags_size, @pact_config.provider_version_branch, filters_ptr, consumer_selectors.size, c_consumer_version_tags, c_consumer_version_tags_size)
          end
        end

        def consumer_selectors
          (!@pact_config.consumer_version_selectors.empty? && @pact_config.consumer_version_selectors) || @consumer_selectors if @pact_config.consumer_version_selectors
        end

        def build_consumer_selectors(verify_only, consumer_name, consumer_branch)
          # if verify_only and consumer_name are defined - select only needed consumer
          if verify_only.present?
            # select proper consumer branch if defined
            if consumer_name.present?
              return [] unless verify_only.include?(consumer_name)
              return [{"branch" => consumer_branch, "consumer" => consumer_name}] if consumer_branch.present?
              return [DEFAULT_CONSUMER_SELECTORS.merge("consumer" => consumer_name)]
            end
            # or default selectors
            return verify_only.map { |name| DEFAULT_CONSUMER_SELECTORS.merge("consumer" => name) }
          end

          # select provided consumer_name
          return [{"branch" => consumer_branch, "consumer" => consumer_name}] if consumer_name.present? && consumer_branch.present?
          return [DEFAULT_CONSUMER_SELECTORS.merge("consumer" => consumer_name)] if consumer_name.present?

          [DEFAULT_CONSUMER_SELECTORS]
        end
      end
    end
  end
end
