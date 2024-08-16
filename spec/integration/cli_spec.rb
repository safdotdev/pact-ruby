require 'open3'
require 'support/cli'

describe "running the pact verify CLI", skip_windows: true do

  include Pact::Support::CLI

  # Running this under RSpec 2 gives different output
  let(:expected_test_output) { %r{1 interaction, 1 failure} }

  describe "running a failing test with --backtrace" do
    let(:command) do
      [
        "bundle exec bin/pact verify",
        "--pact-uri spec/support/test_app_fail.json",
        "--provider-base-url http://foobar:8080",
        "--pact-helper spec/support/pact_helper.rb",
        "--backtrace 2>&1"
      ].join(" ")
    end
    it "displays the full backtrace" do
      execute_command command, with: [/block \(2 levels\) in honour_pactfile/]
    end
  end

  describe "running a failing test without --backtrace" do
    let(:command) do
      [
        "bundle exec bin/pact verify",
        "--pact-uri spec/support/test_app_fail.json",
        "--provider-base-url http://foobar:8080",
        "--pact-helper spec/support/pact_helper.rb 2>&1"
      ].join(" ")
    end
    xit "does not display the full backtrace - need to fix test to work with rspec2" do
      execute_command command, without: [/describe_interaction/]
    end
  end

  describe "running with json output and an output path specified" do
    before do
      FileUtils.rm_rf 'tmp/foo.json'
    end

    let(:command) do
      [
        "bundle exec bin/pact verify",
        "--pact-uri spec/support/test_app_pass.json",
        "--provider-base-url http://foobar:8080",
        "--pact-helper spec/support/pact_helper.rb",
        "--format json",
        "--out tmp/foo.json"
      ].join(" ")
    end

    it "formats the output as json to the specified file" do
      output = `#{command}`
      expect(JSON.parse(File.read('tmp/foo.json'))["examples"].size).to eq 1
      expect(output).to_not match expected_test_output
    end
  end

  describe "running with json output and no output path specified" do
    let(:command) do
      [
        "bundle exec bin/pact verify",
        "--pact-uri spec/support/test_app_pass.json",
        "--provider-base-url http://foobar:8080",
        "--pact-helper spec/support/pact_helper.rb",
        "--format json"
      ].join(" ")
    end

    # TODO - https://github.com/pact-foundation/pact-reference/blob/033a50ab2cba937ab69567b68a42fdf17703f556/rust/pact_verifier/src/lib.rs#L1155
    # verification result does not use logging library
    it "formats the output as json to stdout", skip: "verification result does not use logging library" do
      output = `#{command}`
      expect(JSON.parse(output)["examples"].size).to eq 1
    end
  end

  describe "running with an output path specified" do
    before do
      FileUtils.rm_rf 'tmp/foo.out'
    end

    let(:command) do
      [
        "bundle exec bin/pact verify",
        "--pact-uri spec/support/test_app_pass.json",
        "--provider-base-url http://foobar:8080",
        "--pact-helper spec/support/pact_helper.rb",
        "--out tmp/foo.out"
      ].join(" ")
    end

    it "writes the output to the specified path and not to stdout" do
      output = `#{command}`
      expect(File.read('tmp/foo.out')).to match expected_test_output
      expect(output).to_not match expected_test_output
    end
  end
end
