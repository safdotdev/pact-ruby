require 'pact/doc/generate'
require 'pact/consumer/world'

module Pact
  module Consumer
    module Ffi
      class SpecHooks
        def before_all
          FileUtils.mkdir_p Pact.configuration.pact_dir
        end

        def before_each(_example_description)
          Pact.consumer_world.register_pact_example_ran

          Pact.configuration.logger.info 'Clearing all expectations'
        end

        def after_each(example_description)
          Pact.configuration.logger.info "Verifying interactions for #{example_description}"
          Pact.consumer_world.consumer_contract_builders_ffi.each(&:write_pact)
          Pact.consumer_world.consumer_contract_builders_ffi.each(&:cleanup)
        end

        def after_suite
          return unless Pact.consumer_world.any_pact_examples_ran?

          Pact::Doc::Generate.call
        end
      end
    end
  end
end
