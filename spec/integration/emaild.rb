LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workers/email_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/email_test.log')

describe BackupWorker::EmailStandalone do
  include IntegrationSpecHelper
  
  def email_user
    # tiny account
     ['eternosdude@gmail.com', '3t3rn0s666']
    # huge account
    #['nerolabs@gmail.com', 'borfy622']
    # medium account
    #['simianarmy@gmail.com', 'p00pst3ak']
  end
  
  def verify_content_created
    @bs.backup_emails.size.should > 0
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::EmailStandalone.any_instance.stubs(:load_rails_environment)
    AppSetting.stubs(:first).returns(stub(:master => 'hYgQySo78PN9+LjeBp+dCg=='))
    test_json_conflict
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      setup_db(BackupSite::Gmail, email_user[0], email_user[1])

      @bw = BackupWorker::EmailStandalone.new('test')
      @bw.expects(:save_success_data)
      @bw.run(publish_workitem)
      @bs.reload.needs_initial_scan.should == false
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
      }.should_not change(BackupEmail, :count)
    end
  end
end