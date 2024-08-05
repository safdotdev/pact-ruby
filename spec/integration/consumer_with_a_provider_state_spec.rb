require 'pact/consumer'
require 'pact/consumer/rspec'
load 'pact/consumer/world.rb'
require 'faraday'

describe "A service consumer side of a pact", :pact => true  do
  context "with a provider state" do
    before do
      Pact.clear_configuration

      Pact.service_consumer "Consumer" do
        has_pact_with "Zebra Service" do
          mock_service :zebra_service do
            verify false
            port 1235
          end
        end
      end
    end

    let(:body) { 'That is some good Mallory.' }
    let(:zebra_header) { '*.zebra.com' }

    it "goes like this" do
      zebra_service.
        given(:the_zebras_are_here).
      upon_receiving("a retrieve Mallory request").with(
        method: :get,
        path: '/mallory',
        headers: {'Accept' => 'text/html'}
      ).
      will_respond_with(
        status: 200,
        headers: {
          'Content-Type' => 'text/html',
          'Zebra-Origin' => term(/\*/, zebra_header)
        },
        body: term(/Mallory/, body)
      )
      @mock_server_port = zebra_service.start_mock

      response = Faraday.get(zebra_service.mock_service_base_url + "/mallory", nil, {'Accept' => 'text/html'})
      expect(response.body).to eq body
      expect(response.headers['Content-Type']).to eq 'text/html'
      expect(response.headers['Zebra-Origin']).to eq zebra_header
      # TODO - WARN: Ignoring unsupported matching rules {"match"=>"regex", "regex"=>"\\*"} for path $['header']['Zebra-Origin']
      # fixed by https://github.com/pact-foundation/pact-reference/commit/77814aef9498d029616ac9bbd2f42dce54fe7902
      interactions = Pact::ConsumerContract.from_json(zebra_service.write_pact).interactions
      puts interactions
      expect(interactions.first.provider_state).to eq("the_zebras_are_here")
    end
  end
end
