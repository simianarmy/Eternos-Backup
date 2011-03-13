# Test script for driving backup workers from the command line.

require 'optparse'

# Load rails environment gemfile
LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper'
require File.join(RAILS_ROOT, '/spec/spec_helper') # Load Rails' spec for all the cool modules

require File.dirname(__FILE__) + '/../../lib/workerd'
$: << RAILS_ROOT

#Dir[File.expand_path(File.join(File.dirname(__FILE__), '../../lib/workers/linkedin.rb'))].each {|f| require f}
#require File.join(RAILS_ROOT, 'config/environment.rb')

Workers = {
  'linkedin'   => BackupWorker::Linkedin
}

def say(msg)
  puts msg, "\n" if @verbose
  @logger.info(msg) if @logger
end

def parse_options
  optparse = OptionParser.new do|opts|
    # Set a banner, displayed at the top
    # of the help screen.
    opts.banner = "Usage: backup_driver.rb -r rails-app-dir -b backup-site -u user-id"

    # Define the options, and what they do
    @options[:verbose] = false
    opts.on( '-v', '--verbose', 'Output more information' ) do
      @verbose = @options[:verbose] = true
    end

    @options[:logfile] = nil
    opts.on( '-l', '--logfile FILE', 'Write log to FILE' ) do |file|
      @options[:logfile] = file
      @logger = Logger.new(file)
    end

    @options[:rails_root] = nil
    opts.on( '-r', '--rails-root DIR', 'Path to Rails app') do |root|
      @options[:rails_root] = root
    end

    @options[:backup_site] = nil
    opts.on( '-b', '--site SITE', 'Select backup site.  One of [email|facebook|picasa|rss|twitter|linkedin]') do |site|
      @options[:backup_site] = site
    end

    @options[:user_id] = nil
    opts.on( '-u', '--user ID', 'User ID') do |uid|
      @options[:user_id] = uid
    end

    # This displays the help screen, all programs are
    # assumed to have this option.
    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end
  optparse.parse!
  @options.inspect
  unless @options[:backup_site] && @options[:user_id]
    puts "Missing args.  Run with -h for options." 
    exit
  end
end

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
  end
  unless backup_source
    puts "Could not find a #{@options[:backup_site]} backup site for user!"
    exit
  end
  backup_source
end

def do_backup(backup_source)
  # Create the backup source job
  job = mock('BackupSourceJob')
  job.stubs(
    :backup_job_id      => rand(1000),
    :backup_source   => backup_source,
    :backup_data_set_id => EternosBackup::SiteData.defaultDataSet,
    :status             => BackupStatus::Running)

  worker = Workers[@options[:backup_site]].new(job)
  
  if worker.authenticate
    worker.run
  end
end


describe "backup worker" do
  
  before(:each) do
    @options = {}
  end
  
  describe "linkedin" do
    include UserSpecHelper
    
    let(:linkedin_user) {
      LinkedinUser.create(:linkedin_id => "123", :backup_source_id => @backup_source.id)
    }
    before(:each) do
      user = make_member
      bs = create_backup_site(:name => BackupSite::Linkedin)
      @options[:backup_site] = bs.name
      @options[:user_id] = user.id
      @backup_source = stub('LinkedinAccount', :id => 1,
        :user_id => user.id, :backup_site_id => bs.id,
        :auth_token => '123', :auth_secret => 'shh')
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
        @backup_source.stubs(:auth_token => 'a991050e-df6a-452e-8115-94354d12b21e', 
          :auth_secret => 'a6c75aef-d823-43c9-b024-5d0ef067e825')
      end
      
      it "should run backups" do
        @backup_source.stubs(:linkedin_user => @linkedin_user = stub('LinkedUser'))
        @linkedin_user.expects(:update_profile)
        do_backup @backup_source
      end
    
      describe "on the first backup" do
        before(:each) do
          @backup_source.stubs(:linkedin_user).returns(@profile = linkedin_user)
        end
      
        it "should add the profile data" do
          do_backup @backup_source
          @profile.reload.first_name.should_not be_blank
          @profile.last_name.should_not be_blank
          @profile.linkedin_id.should_not == "123"
          @profile.location_code.should_not be_blank
          @profile.headline.should_not be_blank          
        end

        it "should add associations" do
          do_backup @backup_source
          @profile.reload.linkedin_user_connections.should_not be_empty
          @profile.linkedin_user_positions.should_not be_empty
          @profile.linkedin_user_educations.should_not be_empty
          @profile.linkedin_user_positions.should_not be_empty
          @profile.linkedin_user_comment_like.should_not be_empty
        end
      end
      
      describe "on subsequent backups" do
        before(:each) do
          @backup_source.stubs(:linkedin_user).returns(@profile = linkedin_user)
          do_backup @backup_source
        end
      
        it "should maintain the profile data" do
          do_backup @backup_source
          @profile.reload.first_name.should_not be_blank
          @profile.last_name.should_not be_blank
        end
      end
    end
  end
end


### 

