require 'net/http'
require 'pact/consumer'
require 'pact/consumer/rspec'
require 'faraday'
require 'faraday/multipart'
load 'pact/consumer/world.rb'

describe "A consumer with a file upload", :pact => true  do

  before :all do
    Pact.clear_configuration
    Pact.clear_consumer_world
    Pact.service_consumer "Consumer with a file upload" do
      has_pact_with "A file upload service" do
        mock_service :file_upload_service do
          verify false
          port 7777
        end
      end
    end
  end

  let(:file_to_upload) { File.absolute_path("./spec/support/text.txt") }
  let(:payload) { { file: Faraday::UploadIO.new(file_to_upload, 'text/plain') } }

  let(:connection) do
    Faraday.new(file_upload_service.mock_service_base_url + "/files") do |builder|
      builder.request :multipart
      builder.request :url_encoded
      builder.adapter :net_http
    end
  end

  let(:do_request) { connection.post { |req| req.body = payload } }

  let(:body) do
    "-------------RubyMultipartPost-05e76cbc2adb42ac40344eb9b35e98bc\r\nContent-Disposition: form-data; name=\"file\"; filename=\"text.txt\"\r\nContent-Length: 14\r\nContent-Type: text/plain\r\nContent-Transfer-Encoding: binary\r\n\r\n#{File.read(file_to_upload)}\r\n-------------RubyMultipartPost-05e76cbc2adb42ac40344eb9b35e98bc--\r\n"
  end

  describe "when the content matches", skip: "TODO - rust core - should use file uploader. check content tyep regex works" do
    it "returns the mocked response and verification passes" do
      file_upload_service.
        upon_receiving("a request to upload a file").with({
        method: :post,
        path: '/files',
        body: body,
        headers: {
          "Content-Type" => Pact.term(/^multipart\/form-data(;.*)/, "multipart/form-data; boundary=-----------RubyMultipartPost-05e76cbc2adb42ac40344eb9b35e98bc"),
          "Content-Length" => Pact.like("299")
        }
      }).
        will_respond_with({
        status: 200
      })
      mock_server_port = file_upload_service.start_mock
      puts "rust mock server running on: #{mock_server_port}"
      do_request

      file_upload_service.verify("when the content matches")
    end
  end

  describe "when the content does not match" do
    it "the verification fails" do
      file_upload_service.
        upon_receiving("a request to upload another file").with({
        method: :post,
        path: '/files',
        body: body.gsub('text.txt', 'wrong.txt'),
        headers: {
          # "Content-Type" => Pact.term(/multipart\/form\-data/, "multipart/form-data; boundary=-----------RubyMultipartPost-05e76cbc2adb42ac40344eb9b35e98bc"),
          "Content-Length" => Pact.like("299")
        }
      }).
        will_respond_with({
        status: 200
      })
      mock_server_port = file_upload_service.start_mock
      puts "rust mock server running on: #{mock_server_port}"
      do_request

      expect { file_upload_service.verify }.to raise_error /mismatches/
    end
  end
end
