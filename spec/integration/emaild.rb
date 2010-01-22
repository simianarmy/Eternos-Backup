LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workerd'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/email_test.log')

describe BackupWorker::Email do
  include IntegrationSpecHelper
  
  def email_user
    # tiny account
     ['eternosdude@gmail.com', '3t3rn0s666']
    # medium account
    # Should be Proc asking for credentials
  end
  
  def verify_content_created
    @bs.backup_emails.size.should > 0
  end
  
  before(:all) do
    overload_amqp
    @source = BackupSite::Gmail
    test_json_conflict
    @worker = create_worker_queue
    @worker.run
  end
  
  before(:each) do
    setup_db(BackupSite::Gmail, email_user[0], email_user[1])
    AppSetting.stubs(:first).returns(stub(:master => 'hYgQySo78PN9+LjeBp+dCg=='))
    mock_queues
    @worker.stubs(:send_results).returns(nil)
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      @worker.expects(:save_success_data)
      publish_job(@source)
      @bs.reload.needs_initial_scan.should == false
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      publish_job(@source)
    end
    
    it "should only save new emails" do
      lambda {
        publish_job(@source)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(BackupEmail, :count)
    end
  end
end