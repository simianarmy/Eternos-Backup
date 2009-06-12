begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

ENV['DAEMON_ENV'] = 'test'

require File.dirname(__FILE__) + '/../config/environment'
DaemonKit::Application.running!
require 'backupd'

require File.expand_path(File.dirname(__FILE__) + "/fixjour_builders.rb")

Spec::Runner.configure do |config|
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.include(Fixjour) # This will add the builder methods to your ExampleGroups and not pollute Object
end

