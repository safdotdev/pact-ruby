# frozen_string_literal: true

module Pact
  
    module Matchers
      module V3
        class Integer < Pact::Matchers::Base
          def initialize(template)
            raise MatcherInitializationError, "#{self.class}: #{template} should be an instance of Integer" unless template.is_a?(::Integer)

            super(spec_version: Pact::Matchers::PACT_SPEC_V3, kind: "integer", template: template)
          end
        end
      end
    end
  end

