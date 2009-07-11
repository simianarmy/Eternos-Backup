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
  
  def validate_larch_message(message)
    message.should be_a Larch::IMAP::Message
    message.rfc822.should_not be_blank
  end
  
  def create_gmail(user=email_user, pass=email_pass)
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
        @gmail = create_gmail
      end
      
      it "should fetch mailboxes" do
        @gmail.fetch_emails.should_not be_empty
      end
      
      it "should fetch & parse all emails" do
        @gmail.fetch_emails do |mailbox, id|
          puts "Mailbox: #{mailbox.name} Email: #{id}"
          validate_larch_message e = mailbox[id]
          puts e.rfc822
        end
      end
      
      it "should fetch all emails after cutoff date" do
        @gmail.fetch_emails(Date.today-100) do |mailbox, id|
          puts "Mailbox: #{mailbox.name} Email: #{id}"
          validate_larch_message e = mailbox[id]
        end
      end
      
      it "should not fetch any emails before cutoff date" do
        @gmail.fetch_emails(Date.today+1).should be_empty
      end
    end
  end
end