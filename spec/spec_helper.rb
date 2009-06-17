begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

RAILS_ENV = 'test'
ENV['DAEMON_ENV'] = 'test'

require 'spec'
require File.dirname(__FILE__) + '/rspec_rails_mocha'

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

module FacebookUserSpecHelper
  def create_user(uid=0, session='0')
    FacebookBackup::User.new(uid, session)
  end
  
  def create_real_user
    FacebookBackup::User.new(1005737378, 'c4c3485e22162aeb0be835bb-1005737378', '6ef09f021c983dbd7d04a92f3689a9a5')
  end
end