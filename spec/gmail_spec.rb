# $Idto

require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/email/gmail'

GmailTestUser = 'eternosdude@gmail.com'
GmailTestPass = '3t3rn0s666'

describe EmailGrabber::Gmail do
  def validate_larch_message(message)
    message.should be_a Larch::IMAP::Message
    message.rfc822.should_not be_blank
  end
  
  def create_gmail(user=GmailTestUser, pass=GmailTestPass)
    EmailGrabber::Gmail.new(user, pass)
  end
  
  describe "on create" do
    before(:each) do
      @gmail = create_gmail('a', 'b')
    end
    
    it "should initialize gmail object" do
      @gmail.should be_a EmailGrabber::Gmail
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
        @gmail.fetch_all.should_not be_empty
      end
      
      it "should fetch & parse all emails" do
        @gmail.fetch_all do |mailbox, id|
          validate_larch_message mailbox[id]
        end
      end
      
      it "should fetch all emails after cutoff date" do
        @gmail.fetch_recent(Date.today-100) do |mailbox, id|
          validate_larch_message mailbox[id]
        end
      end
      
      it "should not fetch any emails before cutoff date" do
        @gmail.fetch_recent(Date.today+1).should be_empty
      end
    end
  end
end