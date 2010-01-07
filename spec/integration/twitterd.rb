# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workers/twitter_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/twitter_test.log')

describe BackupWorker::TwitterStandalone do
  include IntegrationSpecHelper
  
  def verify_content_created
    @member.activity_stream.items.twitter.should have_at_least(1).things
    @member.activity_stream.items.twitter.first.should be_a TwitterActivityStreamItem
  end
  
  before(:all) do
    overload_amqp
    BackupWorker::TwitterStandalone.any_instance.stubs(:load_rails_environment)
    BackupSourceJob.stub_chain(:backup_source_id_eq, :newest).returns(nil)
    test_json_conflict
  end

  before(:each) do
  end
  
  describe "initial run" do
    describe "with username & password credentials" do
      it "should save job run info to backup source job record" do
        setup_db(BackupSite::Twitter, 'eternostest', 'w7TpXpO8qAYAUW')
        @bw = BackupWorker::TwitterStandalone.new('test')
        @bw.expects(:save_success_data)
        @bw.expects(:auth_failed).never
        @q = mock_queue_and_publish(@bw)
        @bs.reload.needs_initial_scan.should == false
        verify_successful_backup(BackupSourceJob.last)
        verify_content_created
      end
    end
    
    describe "with oAuth credentials" do
      it "should be authorized with valid token & secret" do
        setup_db(BackupSite::Twitter, nil, nil, 
        :auth_token => '54722862-X4bagmt3crjGLNgeVFvK0fxkLDZMcybK8pBqKtpwU',
        :auth_secret => 'Z5gbyi8EiuRXUx1i7bTdrHsrlK0bb7N9lNOUBdLOfA')
        @bw = BackupWorker::TwitterStandalone.new('test')
        @bw.expects(:auth_failed).never
        @q = mock_queue_and_publish(@bw)
        @bs.reload.needs_initial_scan.should == false
        verify_successful_backup(BackupSourceJob.last)
        verify_content_created
      end
    end  
  end
  
  describe "subsequent runs" do
    before(:each) do
      setup_db(BackupSite::Twitter, 'eternostest', 'w7TpXpO8qAYAUW')
      @bw = BackupWorker::TwitterStandalone.new('test')
      @bw.stubs(:save_success_data)
      @q = mock_queue_and_publish(@bw)
    end
    
    it "should not re-save feed entries" do
      lambda {
        @q.publish('go')
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@member.activity_stream.items, :count)
    end
  end
end