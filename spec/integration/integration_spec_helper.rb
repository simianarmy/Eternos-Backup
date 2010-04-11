# $Id$

# Helper module for integration testing

require 'moqueue'

module IntegrationSpecHelper
  include WorkItemSpecHelper
  
  # def create_member(attributes={})
  #     passwords = {:password => 'shoe1str1ng', :password_confirmation => 'shoe1str1ng'}
  #     fb_id = attributes[:fb_id] || nil
  #     
  #     user = User.create({
  #       :email => Faker::Internet.email,
  #       :first_name => Faker::Name.first_name,
  #       :last_name => Faker::Name.last_name,
  #       :password => passwords[:password],
  #       :password_confirmation => passwords[:password_confirmation],
  #       :facebook_uid => fb_id
  #     }.merge(attributes))
  #     user.activate!
  #     User.find(user.id) # Return as Member object
  #   end
    
  def test_json_conflict
    {:a => []}.to_json.should == "{\"a\":[]}"
  end
  
  def load_db(backup_site_name)
    @member = Member.find_by_first_name(backup_site_name)
    @bs = @member.backup_sources.by_site(backup_site_name).first
    @site = @bs.backup_site
  end
  
  def setup_db(backup_site_name, username, password, opts={})
    # I guess this is fixed in Rails/rspec now (tables weren't emptying before), 
    # also they say don't use DDL statements in transactions
    #(ActiveRecord::Base.connection.tables - %w{schema_migrations}).each do |table_name|
    #  ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table_name};")
    #end
    
    @member = create_member
    @member.update_attributes(:first_name => backup_site_name)
    @site = create_backup_site(:name => backup_site_name)
    setup_backup_source(backup_site_name, username, password, opts)
  end
    
  def publish_workitem
    ruote_backup_workitem(@member, @bs)
  end
  
  def create_worker_queue
    BackupWorker::Queue.any_instance.expects(:load_rails_environment)
    BackupWorker::Queue.any_instance.stubs(:recent_job?).returns(false)
    MessageQueue.stubs(:start).yields
    BackupSourceJob.stubs(:cleanup_connection).yields(nil)
    q = BackupWorker::Queue.new('test')
  end
  
  # Sets up message queue mocks, runs backup worker daemon
  def mock_queues
    reset_broker
    
    #MQ.expects(:queue).with(feedback_queue).at_least_once.returns(stub(:publish => nil))
    # The code below won't work as long as we are stubbing Thread.new!!
    # b/c moqueue uses Thread.new so all kind of bad happens...
    q = MQ.new.queue(feedback_queue)
    q.subscribe {|header, msg| puts msg }
  end
  
  def publish_job(site, workitem=publish_workitem)
    q = MessageQueue.backup_worker_topic
    q.publish(workitem, :key => MessageQueue.backup_worker_topic_route(site))
  end
    
  def verify_successful_backup(bj)
    bj.created_at.should <= bj.finished_at
    bj.finished_at.should_not == nil
    bj.status.should == BackupStatus::Success
    bj.percent_complete.should == 100
    bj.error_messages.should == nil
  end
  
  private
  
  def setup_backup_source(site, username=nil, password=nil, opts={})
    @bs = case site
    when BackupSite::Facebook
      BackupSource.create(:backup_site => @site, :member => @member)
    when BackupSite::Twitter
      BackupSource.create({:backup_site => @site, :member => @member, 
        :auth_login => username, :auth_password => password}.merge(opts))
    when BackupSite::Blog
      FeedUrl.create(:backup_site => @site, :member => @member, 
        :rss_url => opts[:rss_url]
        )
    when BackupSite::Gmail
      GmailAccount.create(:backup_site => @site, :member => @member, 
        :auth_login => username, :auth_password => password)
    when BackupSite::Picasa
      PicasaWebAccount.create(:backup_site => @site, :member => @member, :auth_token => password)
    else
      raise "#{site} backup source not supported!"
    end
  end
end