# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workerd'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/twitter_test.log')

describe BackupWorker::Twitter do
  include IntegrationSpecHelper
  
  def verify_content_created
    @member.activity_stream.items.twitter.should have_at_least(1).things
    @member.activity_stream.items.twitter.first.should be_a TwitterActivityStreamItem
  end
  
  before(:all) do
    overload_amqp
    BackupSourceJob.stub_chain(:backup_source_id_eq, :newest).returns(nil)
    test_json_conflict
    @source = BackupSite::Twitter
    @worker = create_worker_queue
    @worker.run
  end

  before(:each) do
    mock_queues
  end
  
  describe "initial run" do
    describe "with username & password credentials" do
      it "should save job run info to backup source job record" do
        setup_db(BackupSite::Twitter, 'eternostest', 'w7TpXpO8qAYAUW')
        @worker.expects(:save_success_data)
        @worker.expects(:auth_failed).never
        publish_job(@source)
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
        @worker.expects(:auth_failed).never
        publish_job(@source)
        @bs.reload.needs_initial_scan.should == false
        verify_successful_backup(BackupSourceJob.last)
        verify_content_created
      end
    end  
  end
  
  describe "subsequent runs" do
    before(:each) do
      setup_db(BackupSite::Twitter, 'eternostest', 'w7TpXpO8qAYAUW')
      publish_job(@source)
    end
    
    it "should not re-save feed entries" do
      lambda {
        publish_job(@source)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@member.activity_stream.items, :count)
    end
  end
end