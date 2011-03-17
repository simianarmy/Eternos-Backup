# Test script for driving backup workers from the command line.

# Load rails environment gemfile
LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper'
require File.join(RAILS_ROOT, '/spec/spec_helper') # Load Rails' spec for all the cool modules

require File.dirname(__FILE__) + '/../../lib/workerd'
$: << RAILS_ROOT

Workers = {
  'linkedin'   => BackupWorker::Linkedin,
  'facebook'  => BackupWorker::Facebook
}


def get_backup_source
  user = nil
  unless user = User.find_by_id(@options[:user_id])
    puts "Could not find user with ID = #{@options[:user_id]}"
    exit
  end
  unless Workers.has_key? @options[:backup_site]
    say "backup site: #{@options[:backup_site]} not found!"
    exit
  end
  say "Running backup for #{@options[:backup_site]} site, user #{user.id}"
  # Get user's backup source object
  backup_source = nil
  case @options[:backup_site]
  when 'linkedin'
    backup_source = user.backup_sources.linkedin.first
  when 'facebook'
    backup_source = user.backup_sources.facebook.first
  end
  unless backup_source
    puts "Could not find a #{@options[:backup_site]} backup site for user!"
    exit
  end
  backup_source
end

def do_backup(backup_source, action=nil)
  # Create the backup source job
  job = mock('BackupSourceJob')
  job.stubs(
    :backup_job_id      => rand(1000),
    :backup_source   => backup_source,
    :backup_data_set_id => EternosBackup::SiteData.defaultDataSet,
    :status             => BackupStatus::Running)

  worker = Workers[@options[:backup_site]].new(job)
  worker.stubs(:rest_client?).returns(true)
  worker.logger = stub_everything
    
  if worker.authenticate
    worker.send(action||:run)
  end
end


describe "backup worker" do
  
  before(:each) do
    @options = {}
    DaemonKit.stubs(:logger).returns(stub_everything)
  end
  
  describe "facebook for rest app" do
    include UserSpecHelper
  
    before(:each) do
      @user = make_member
      bs = create_backup_site(:name => BackupSite::Facebook)
      @options[:backup_site] = bs.name
      @options[:user_id] = @user.id
      @backup_source = stub('FacebookAccount', :id => 1,
        :user_id => @user.id, :backup_site_id => bs.id,
        :auth_login => '123456', :auth_token => '123', :auth_secret => 'shh')
    end
    
    it "should fail without errors with no credentials" do
      lambda {
        @backup_source.stubs(:auth_token => nil) 
        do_backup(@backup_source)
      }.should_not raise_error
    end
    
    it "should fail without errors with invalid credentials" do
      lambda {
        do_backup(@backup_source)
      }.should_not raise_error
    end
    
    describe "with valid credentials" do
      before(:each) do
        @backup_source.stubs(:auth_login => "1819789912",
          :auth_token => "4d2f7e6abd1505f1e4da59c6-1819789912", 
          :auth_secret => "eef70b50ae76ee1d78fc18594410a30b")
        @backup_source.expects(:logged_in!)
      end
    
      describe "on the first backup" do
        describe "on profile backup" do
          it "should add the profile data" do
            @user.profile.expects(:update_attribute)
            do_backup @backup_source, :save_profile
          end
        end

        it "should add friends and groups" do
          do_backup @backup_source, :save_friends
        end
      end
      
      describe "on subsequent backups" do
        before(:each) do
          do_backup @backup_source, :save_profile
          do_backup @backup_source, :save_friends
        end
      
        it "should save changes to the profile data" do
          do_backup @backup_source, :save_profile
          # Check facebook data for updates
        end
      end
    end
  end
end


### 

