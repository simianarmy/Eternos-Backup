begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end
require 'spork'

ENV['RAILS_ENV'] = ENV['DAEMON_ENV'] = 'test'

# Where did be_false, be_empty, be_blank, be_nil, and other matchers go????

require File.dirname(__FILE__) + '/../config/environment'
# May have to comment this out...
#DaemonKit::Application.running!

require 'backupd'

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However, 
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  Spec::Runner.configure do |config|
    # == Mock Framework
    #
    # RSpec uses it's own mocking framework by default. If you prefer to
    # use mocha, flexmock or RR, uncomment the appropriate line:
    #
    config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    config.include(Fixjour) if defined? Fixjour# This will add the builder methods to your ExampleGroups and not pollute Object
  end
  
  # TODO: Make Rails environment loading optional
  require RAILS_ROOT + "/config/environment"
  require 'fixjour' 
  Rails::Initializer.run do |config|
    config.cache_classes = false
  end
  require 'spec/autorun'
  require 'spec/rails'
  require File.dirname(__FILE__) + '/rspec_rails_mocha'
  require File.dirname(__FILE__) + '/stub_chain_mocha'

  require RAILS_ROOT + "/spec/fixjour_builders.rb"

  module BackupHelperSpecHelper
    def stub_logger
      DaemonKit.stubs(:logger).returns(stub('logger', :debug => nil, :info => nil, :error => nil))
    end
  end

  module FacebookUserSpecHelper
    def create_user(uid=0, session='0')
      FacebookBackup::User.new(uid, session)
    end

    def create_real_user
      FacebookBackup::User.new(1005737378, 'c4c3485e22162aeb0be835bb-1005737378', '6ef09f021c983dbd7d04a92f3689a9a5')
    end
  end

  module WorkItemSpecHelper
    def ruote_workitem
        json = <<-JSON
        {"last_modified": "2009/04/23 12:49:07 +0200",
          "type": "OpenWFE::InFlowWorkItem",
          "participant_name": "ruote",
          "attributes": {"job_id": 100},
          "dispatch_time": "2009/04/23 12:49:07 +0200",
          "flow_expression_id": {"workflow_definition_url": "field:__definition",
            "expression_name": "toto",
            "workflow_definition_name": "TestExternal",
            "owfe_version": "0.9.21",
            "workflow_definition_revision": "0",
            "workflow_instance_id": "20090413-juduhojewo",
            "engine_id": "ruote_rest",
            "expression_id": "0.0.0.0.1"}}
JSON
    end

    def ruote_backup_workitem(member, source)
        json = <<-JSON
            {"last_modified": "2009/04/23 12:49:07 +0200",
              "type": "OpenWFE::InFlowWorkItem",
              "participant_name": "backup",
              "attributes": {"target": {"source": "#{source.backup_site.name}", "id": #{source.id}}, "job_id": 100, "user_id": #{member.id}, "reply_queue": "ruote_backup_feedback"},
              "dispatch_time": "2009/04/23 12:49:07 +0200",
              "flow_expression_id": {"workflow_definition_url": "field:__definition",
                "expression_name": "toto",
                "workflow_definition_name": "TestExternal",
                "owfe_version": "0.9.21",
                "workflow_definition_revision": "0",
                "workflow_instance_id": "20090413-juduhojewo",
                "engine_id": "ruote_rest",
                "reply_queue": "reply_q",
                "expression_id": "0.0.0.0.1"}}
JSON
    end
  end
  
  module GoogleAuthSpecHelper
    require File.join(RAILS_ROOT, 'lib/google_backup')
    
    def valid_google_auth_token
      "CPTLiMT9GRDmgNn0_P____8B"
    end
    
    def create_picasa_client
      GoogleBackup::Auth::Picasa.new(:auth_token => valid_google_auth_token)
    end
  end

end