# $Id$

require File.join(File.expand_path(File.dirname(__FILE__)) + '/../../eternos.com/config/environment')
ENV['RAILS_ENV'] ||= 'test'

# Populate database for testing backup daemons
namespace :db do
  desc "Fills required records for backup daemons"
  task :bootstrap_backups => :environment do
    require 'faker'

    [BackupSite, Member, BackupSource].each(&:delete_all)
    
    puts "Populating sites"
    BackupSite.names.each do |site|
      BackupSite.create(:name => site)
    end

    # Create member with backup sources
    puts "Populating users"
    member = Member.create(:email => Faker::Internet.email,
    :first_name => Faker::Name.first_name,
    :last_name => Faker::Name.last_name,
    :password => 'password',
    :password_confirmation => 'password')

    puts "Populating backup sources"
    # Facebook - fixtures would be nice to have for multiple choices
    member.update_attributes(:facebook_id => 1005737378)
    member.set_facebook_session_keys('c4c3485e22162aeb0be835bb-1005737378', '6ef09f021c983dbd7d04a92f3689a9a5')
    member.backup_sources.create(:backup_site => BackupSite.find_by_name(BackupSite::Facebook))
    # Twitter
    member.backup_sources.create(:backup_site => BackupSite.find_by_name(BackupSite::Twitter), 
      :auth_login => 'eternostest', :auth_password => 'w7TpXpO8qAYAUW')
    # Blog
    member.backup_sources << FeedUrl.create(:backup_site => BackupSite.find_by_name(BackupSite::Blog),
      :rss_url => 'http://feeds.feedburner.com/railscasts')
    # Email
    member.backup_sources << GmailAccount.create(:backup_site => BackupSite.find_by_name(BackupSite::Gmail),
      :auth_login => 'eternosdude@gmail.com', :auth_password => '3t3rn0s666')
  end
end