# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workers/twitter_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/twitter_test.log')

describe BackupWorker::TwitterStandalone do
  include IntegrationSpecHelper
  
  def verify_content_created
    @member.activity_stream.items.twitter.should_not be_empty
    @member.activity_stream.items.twitter.first.should be_a TwitterActivityStreamItem
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::TwitterStandalone.any_instance.stubs(:load_rails_environment)
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      setup_db(BackupSite::Twitter, 'eternostest', 'w7TpXpO8qAYAUW')
      @bw = BackupWorker::TwitterStandalone.new('test')
      @bw.expects(:save_success_data)
      @bw.run(publish_workitem)
      @bs.reload.needs_initial_scan.should be_false
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      load_db BackupSite::Twitter
      @bw = BackupWorker::TwitterStandalone.new('test')
      @bw.expects(:save_success_data)
    end
    
    it "should not re-save feed entries" do
      lambda {
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@member.activity_stream.items, :count)
    end
  end
end