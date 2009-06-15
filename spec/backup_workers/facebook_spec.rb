# $Id$

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/facebook_worker'
require 'active_record/base'


describe BackupWorker::Facebook do
  include MQSpecHelper

  describe "on backup" do
    before(:each) do
      BackupWorker::Facebook.any_instance.expects(:load_rails_environment)
      @bw = BackupWorker::Facebook.new(ENV['DAEMON_ENV'])
      @job = mock('BackupSourceJob')
      @job.stubs(:backup_source).returns(@bs = mock('BackupSource'))
      @bs.stubs(:facebook_uid).returns('100')
      @bs.stubs(:facebook_session_key).returns('abc')
      @bs.stubs(:facebook_secret_key).returns('shhh')
      FacebookBackup::User.expects(:new).with(@bs.facebook_uid, @bs.facebook_session_key, @bs.facebook_secret_key).returns(@fb_user)
      @fb_user.expects(:login!)
    end
    
    describe "logging in to facebook" do
      it "should fail & return on login failure" do
        @fb_user.stubs(:logged_in?).returns(false)
        @bw.expects(:fail)
        @bw.backup(@job)
      end
    end
  end
end
