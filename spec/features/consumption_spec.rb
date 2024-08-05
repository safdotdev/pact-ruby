require 'net/http'
require 'pact/consumer'
require 'pact/consumer/rspec'
load 'pact/consumer/world.rb'

describe "A service consumer side of a pact", :pact => true  do

  before do
    Pact.clear_configuration
    Pact.clear_consumer_world
  end

  describe "blah" do
    describe "thing" do

      it "goes a little something like this" do

        Pact.service_consumer "Consumer" do
          has_pact_with "Alice Service" do
            mock_service :alice_service do
              verify true
              port 8888
            end
          end

          has_pact_with "Bob" do
            mock_service :bob_service do
              verify false
              port 4321
            end
          end
        end

        alice_service.
          upon_receiving("a retrieve Mallory request").with({
          method: :get,
          path: '/mallory'
        }).
          will_respond_with({
          status: 200,
          headers: { 'Content-Type' => 'text/html' },
          body: term(/Mallory/, 'That is some good Mallory.')
        })

        bob_service.
          upon_receiving('a create donut request').with({
          method: :post,
          path: '/donuts',
          body: {
            "name" => term(/[\s\S]*/, 'Bob')
          },
          headers: {'Accept' => 'text/plain', "Content-Type" => 'application/json'}
        }).
          will_respond_with({
          status: 201,
          body: 'Donut created.'
        })
        bob_service.
          upon_receiving('a delete charlie request').with({
          method: :delete,
          path: '/charlie'
        }).
          will_respond_with({
          status: 200,
          body: /deleted/
        })
        bob_service.
          upon_receiving('an update alligators request').with({
            method: :put,
            path: '/alligators',
            body: [{"name" => 'Roger' }]
        }).
          will_respond_with({
            status: 200,
            body: [{"name" => "Roger", "age" => 20}]
        })
        @alice_mock_server_port = alice_service.start_mock
        @bob_mock_server_port = bob_service.start_mock

        alice_response = Net::HTTP.get_response(URI('http://localhost:8888/mallory'))

        expect(alice_response.code).to eql '200'
        expect(alice_response['Content-Type']).to eql 'text/html'
        expect(alice_response.body).to eql 'That is some good Mallory.'

        uri = URI('http://localhost:4321/donuts')
        post_req = Net::HTTP::Post.new(uri.path)
        post_req['Accept'] = "text/plain"
        post_req['Content-Type'] = "application/json"
        post_req.body = {"name" => "Bobby"}.to_json
        bob_post_response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request post_req
        end

        expect(bob_post_response.code).to eql '201'
        expect(bob_post_response.body).to eql 'Donut created.'

        uri = URI('http://localhost:4321/alligators')
        post_req = Net::HTTP::Put.new(uri.path)
        post_req['Content-Type'] = "application/json"
        post_req.body = [{"name" => "Roger"}].to_json
        bob_post_response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request post_req
        end
        # bob_service.write_pact()
        expect(bob_post_response.code).to eql '200'
        expect(bob_post_response.body).to eql([{"age" => 20, "name" => "Roger"}].to_json)

        expect{ bob_service.verify }.to raise_error /missing-request/
      end

    end
  end
end
