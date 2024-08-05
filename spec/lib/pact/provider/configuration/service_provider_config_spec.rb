require 'pact/provider/configuration/service_provider_config'

module Pact
  module Provider
    module Configuration
      describe ServiceProviderConfig do
        describe "app" do

          let(:app_block) { ->{ Object.new } }

          subject { ServiceProviderConfig.new("1.2.3'", "main", [], true, 'http://ci/build/1', 'http://localhost:9292', &app_block) }

          it "should execute the app_block each time" do
            expect(subject.app.object_id).to_not equal(subject.app.object_id)
          end
        end
      end
    end
  end
end
