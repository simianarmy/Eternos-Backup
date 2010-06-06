require File.dirname(__FILE__) + '/config/boot'

require 'rake'
require 'active_record'
require 'yaml'
require 'daemon_kit/tasks'

Dir[File.join(File.dirname(__FILE__), 'tasks/*.rake')].each { |rake| load rake }
daemon_env = ENV['DAEMON_ENV'] || 'development'

desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x"
task :migrate => :environment do
  ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
end

task :environment do
  ActiveRecord::Base.establish_connection YAML.load_file('config/database.yml')[daemon_env]
  ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'a'))
end
