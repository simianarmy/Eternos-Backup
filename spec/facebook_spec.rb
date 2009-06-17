# $Id$

require File.dirname(__FILE__) + '/spec_helper.rb'

describe FacebookBackup do
  include FacebookUserSpecHelper
  
  it "should load default facebooker yaml file and return environment settings" do
    ENV['DAEMON_ENV'] = 'test'
    (c = FacebookBackup.load_config).should be_an_instance_of Hash
    c['api_key'].should_not be_nil
    c['secret_key'].should_not be_nil
  end
  
  describe FacebookBackup::Session do
    describe "on create" do
      it "should create facebook desktop session object" do
        lambda {
          @session = FacebookBackup::Session.create
        }.should_not raise_error
    
        @session.should be_a_kind_of Facebooker::Session::Desktop
        @session.login_url.should match(/api_key=#{FacebookBackup.load_config['api_key']}/)
      end
    end
    
    describe "on login" do
      before(:each) do
        @session = FacebookBackup::Session.create
      end
      
      it "should fail if not passed user settings" do
        lambda {
          @session.connect
        }.should raise_error ArgumentError
      end
    end
  end
    
  describe FacebookBackup::User do  
    describe "on new" do
      it "should require user id and session key on initialize" do
        lambda {
          FacebookBackup::User.new
        }.should raise_error ArgumentError
        
        create_user.should be_an_instance_of FacebookBackup::User
      end
    end
    
    describe "a valid object" do
      before(:each) do
         @user = create_user(100, 'foo')
       end
       
      it "should return a valid session" do
        lambda {
          @user.session.should be_an_instance_of FacebookBackup::Session
        }.should_not raise_error NameError
      end
    
      describe "on login" do
        before(:each) do
        end
    
        it "should return attribute values" do
          @u = create_user(100, 'foo')
          @u.id.should == 100
          @u.session_key.should == 'foo'
        end
    
        it "should fail with invalid session key" do
          @u = create_user
          @u.login!
          @user.should_not be_logged_in
        end
    
        it "should login successfully with valid session & secret keys" do
          lambda {
            @user = create_real_user
            @user.login!
            @user.should be_logged_in
          }.should_not raise_error
        end
      end
      
      describe "logged in" do
        before(:each) do
          @user = create_real_user
          @user.login!
        end
        
        it "should return a user profile hash" do
          p = @user.profile
          p.should_not be_empty
        end  
        
        describe "photo albums" do
          before(:each) do
            @albums = @user.albums
          end
          
          it "should return photo album collection" do
            @albums.should_not be_empty
            @albums.each {|a| a.should be_an_instance_of FacebookPhotoAlbum}
          end
          
        end
      end
    end
  end
end
    