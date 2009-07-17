LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workers/email_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/email_test.log')

describe BackupWorker::EmailStandalone do
  include IntegrationSpecHelper
  
  def email_user
    'eternosdude@gmail.com'
  end
  
  def email_pass
    '3t3rn0s666'
  end
  
  def verify_content_created
    @bs.backup_emails.should_not be_empty
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::EmailStandalone.any_instance.stubs(:load_rails_environment)
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      setup_db(BackupSite::Gmail, email_user, email_pass)

      @bw = BackupWorker::EmailStandalone.new('test')
      @bw.expects(:save_success_data)
      @bw.run(publish_workitem)
      @bs.reload.needs_initial_scan.should be_false
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      load_db BackupSite::Gmail

      @bw = BackupWorker::EmailStandalone.new('test')
      @bw.expects(:save_success_data)
    end
    
    it "should only save new emails" do
      lambda {
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@member.activity_stream.items, :count)
    end
  end
end