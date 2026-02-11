RSpec::Core::RakeTask.new('spec') do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = '--require spec_helper --require rails_helper'
end

RSpec::Core::RakeTask.new('pact:spec') do |task|
  task.pattern = 'spec/pact/providers/**/*_spec.rb'
  task.rspec_opts = ['-t pact', '--require spec_helper --require rails_helper']
end

RSpec::Core::RakeTask.new('pact:verify') do |task|
  task.pattern = 'spec/pact/consumers/*_spec.rb'
  task.rspec_opts = ['-t pact', '--require spec_helper --require rails_helper']
end

# Need to run this in separate process because left over state from
# testing the actual pact framework messes up the tests that actually
# use pact.
# RSpec::Core::RakeTask.new('spec:provider') do |task|
#   task.pattern = 'spec/service_providers/**/*_test.rb'
# end

# task :set_active_support_on do
#   ENV['LOAD_ACTIVE_SUPPORT'] = 'true'
# end

# desc 'This is to ensure that the gem still works even when active support JSON is loaded.'
# task : [:set_active_support_on] do
#   Rake::Task['pact'].execute
# end


desc 'Run all spec tasks'
task 'spec:all' => ['spec', 'pact:spec', 'pact:verify']