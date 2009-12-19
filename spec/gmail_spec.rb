# $Id$

require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/integration/integration_spec_helper'
require 'active_support'
require 'active_support/core_ext/array/extract_options'
require File.dirname(__FILE__) + '/../lib/workers/backupd_worker'
require File.dirname(__FILE__) + '/../lib/email/email_grabber'
require File.dirname(__FILE__) + '/../lib/email/imap_gmail'

describe EmailGrabber::IMAP::Gmail do
  include IntegrationSpecHelper
  
  def email_user
    # tiny account
    ['eternosdude@gmail.com', '3t3rn0s666']
  end
  
  def validate_larch_message(message)
    message.should be_a Larch::IMAP::Message
    message.rfc822.should_not be_blank
  end
  
  def create_gmail(user, pass)
    EmailGrabber.create('gmail', user, pass)
  end
  
  describe "on create" do
    before(:each) do
      @gmail = create_gmail('a', 'b')
    end
    
    it "should initialize gmail object" do
      @gmail.should be_a EmailGrabber::IMAP::Gmail
    end
  end
  
  describe "on connect" do
    describe "with invalid credentials" do
      before(:each) do
        @gmail = create_gmail('a', 'b')
      end

      it "should fail with invalid auth error" do
        lambda {@gmail.connect}.should raise_error
      end
    end
    
    describe "with valid credentials" do
      
      before(:each) do
        @gmail = create_gmail(email_user[0], email_user[1])
      end
      
      it "should fetch mailboxe & ids" do
        mailbox, ids = @gmail.fetch_email_ids
        ids.should_not be_empty
      end
      
      it "should fetch all emails after cutoff date" do
        mail = Hash.new { |h,k| h[k] = 0 }
        mailbox, ids = @gmail.fetch_email_ids(:start_date => Date.today-100)
        ids.should_not be_empty
      end
      
      it "should not fetch any emails before cutoff date" do
        mailbox, ids = @gmail.fetch_email_ids(:start_date => Date.today+1)
        ids.should be_empty
      end
      
      it "should fetch emails by id" do
        @gmail.fetch_email_ids(:start_date => Date.today-100) do |mailbox, id|
          puts "Mailbox: #{mailbox.name} Email: #{id[0]}"
          validate_larch_message e = id[0]
          break
        end
      end
    end
  end
end