require 'pact/consumer'
require 'pact/consumer/rspec'
load 'pact/consumer/world.rb'

describe 'A service consumer side of a pact', pact: true do
  context 'with no matching interaction found' do
    # let(:expected_response) do
    #   {
    #     'message' => 'No interaction found for GET /path',
    #     'interaction_diffs' => [{
    #       'description' => 'a request that will not be properly matched',
    #       'provider_state' => 'something',
    #       'body' => {
    #         'a' => {
    #           'EXPECTED' => 'some body',
    #           'ACTUAL' => 'not matching body'
    #         }
    #       }
    #     }]
    #   }
    # end
    # let(:expected_response) do
    #   { 'error' => 'Request-Mismatch : HttpRequest { method: "GET", path: "/path", query: None, headers: Some({"content-type": ["application/json"], "accept-encoding": ["gzip;q=1.0", "deflate;q=0.6", "identity;q=0.3"], "host": ["localhost:1236"], "user-agent": ["Ruby"], "content-length": ["25"], "accept": ["*/*"]}), body: Present(b"{\"a\":\"not matching body\"}", Some(ContentType { main_type: "application", sub_type: "json", attributes: {}, suffix: None }), None), matching_rules: MatchingRules { rules: {} }, generators: Generators { categories: {} } }' }
    # end
    let(:expected_response) do
      'Request-Mismatch'
    end

    it "returns an error" do
      Pact.clear_configuration

      Pact.service_consumer "Consumer" do
        has_pact_with "Mary Service" do
          mock_service :mary_service do
            verify false
            port 1236
          end
        end
      end

      mary_service
      .given("something")
      .upon_receiving("a request that will not be properly matched")
      .with(method: 'get', path: '/path', body: {a: 'some body'}, headers: {'Content-Type' => 'application/json'})
      .will_respond_with(status: 200)
      @mock_server_port = mary_service.start_mock

      uri = URI('http://localhost:1236/path')
      post_req = Net::HTTP::Get.new(uri.path)
      post_req['Content-Type'] = "application/json"
      post_req.body = {a: "not matching body"}.to_json
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request post_req
      end

      expect(response.body).to include(expected_response)
    end
  end
end
