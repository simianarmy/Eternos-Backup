# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workers/rss_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/rssd_test.log')

describe BackupWorker::RSSStandalone do
  include IntegrationSpecHelper
  
  def verify_content_created
    @bs.feed.should_not be_nil
    #@bs.feed.etag.should_not be_nil
    @bs.feed.last_modified.should_not be_nil
    @bs.feed.entries.should_not be_empty
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::RSSStandalone.any_instance.stubs(:load_rails_environment)
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      setup_db BackupSite::Blog
      @bw = BackupWorker::RSSStandalone.new('test')
      @bw.expects(:save_success_data)
      @bw.run(publish_workitem)
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      load_db
      @bw = BackupWorker::RSSStandalone.new('test')
      @bw.expects(:save_success_data)
    end
    
    it "should not re-save feed entries" do
      lambda {
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@bs.feed.entries, :count)
    end
  end
end