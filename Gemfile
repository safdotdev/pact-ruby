source 'https://rubygems.org'

# Specify your gem's dependencies in pact.gemspec
gemspec

# If rspec-mocks is not locked, spec/lib/pact/consumer/configuration_spec.rb fails on Ruby 3.0
# Should raise an issue, but no time right now.
# #<Pact::MockService::AppManager:0x00007fcf21410e68 @apps_spawned=false, @app_registrations=[]> received :register_mock_service_for with unexpected arguments
#   expected: ("Mock Provider", "http://localhost:1234", {:find_available_port=>false, :pact_specification_version=>"1"})
#        got: ("Mock Provider", "http://localhost:1234", {:find_available_port=>false, :pact_specification_version=>"1"})
# Diff:

gem "rspec-mocks", "3.10.2"
gem "appraisal", "~> 2.5"

if ENV['X_PACT_DEVELOPMENT']
  gem "pact-ffi", path: '../pact-ruby-ffi'
  gem "pact-support", path: '../pact-support'
  # gem "pact-mock_service", path: '../pact-mock_service'
  gem "pry-byebug"
end
gem 'pact-support', '~> 1.16', '>= 1.16.9', git: 'https://github.com/safdotdev/pact-support.git', branch: 'feat/ffi'
# gem 'pact-ruby-ffi', '>=0.4.22', git: 'https://github.com/safdotdev/pact-ruby-ffi.git', branch: 'feat/ffi'


group :local_development do
  gem "pry-byebug"
end

group :test do
  gem 'faraday', '~>2.0'
  gem 'faraday-retry', '~>2.0'
  gem 'rackup', '~> 2.1'
end
