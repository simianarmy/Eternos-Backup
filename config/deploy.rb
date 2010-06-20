
require "eycap/recipes"
require 'release_tagger'

# The :autotagger_stages variable is required
#set :autotagger_stages, [:test, :staging, :production]

set :stages, %w(staging production)
set :default_stage, "staging"
require "capistrano/ext/multistage"

# Set some globals
default_run_options[:pty] = true
set :application, "EternosBackup"

# Deployment
set :user, 'deploy'
#set :runner, 'mmauger'

# For Subversion repo configuration
#set :scm, 'subversion'
#set :svn_user, ENV['svn_user'] || "marc"
#set :svn_password, ENV['svn_password'] || Proc.new { Capistrano::CLI.password_prompt('SVN Password: ') }
# set :repository,
#   Proc.new { "--username #{svn_user} " +
#              "--password #{svn_password} " +
#              "--no-auth-cache " + 
#              "https://eternos.unfuddle.com/svn/eternos_system/trunk" }
#set :deploy_via, :remote_cache

# For Git
set :repository,    'git@github.com:simianarmy/Eternos-Backup.git'
set :monit_group,   "#{application}"
set :scm,           :git
set :git_enable_submodules, 1
set :environment_host, 'localhost'
set :deploy_via, :remote_cache

# comment out if it gives you trouble. newest net/ssh needs this set.
ssh_options[:paranoid] = false
default_run_options[:pty] = true
ssh_options[:forward_agent] = true
default_run_options[:pty] = true # required for svn+ssh:// andf git:// sometimes

# This will execute the Git revision parsing on the *remote* server rather than locally
set :real_revision, 			lambda { source.query_revision(revision) { |cmd| capture(cmd) } }

# No sudo
set :use_sudo, false

# File list in the config_files setting will be copied from the
# 'deploy_to' directory into config, overwriting files from the repo
# with the same name
set :config_files, %w{ }

# List any work directories here that you need persisted between
# deployments. They are created in 'deploy_to'/shared and symlinked
# into the root directory of the deployment.
set :shared_children, %w{log tmp}

# Record our dependencies
depend :remote, :directory, "/usr/local/src"

# For git auto_tagger
# before "deploy:update_code", "release_tagger:set_branch"
# after  "deploy", "release_tagger:write_tag_to_shared"
# after  "deploy", "release_tagger:print_latest_tags"

# Specify erlang distribution name 
# set :erlang
# Hook into capistrano's events

before "deploy:setup", "deploy:install_software"
after "deploy:symlink", "deploy:fix_binaries"

# Create some tasks related to deployment
namespace :deploy do
  def god_daemon_group_name
    "eternos-backup_#{stage}"
  end
  
  desc "Get the current revision of the deployed code"
  task :get_current_version do
    run "cat #{current_path}/REVISION" do |ch, stream, out|
      puts "Current revision: " + out.chomp
    end
  end
  
  task :restart do
    run "#{sudo} monit restart backupd"
    run "#{sudo} monit restart workerd"
  end
  
  task :stop_daemons do
    #run "#{sudo} monit stop backupd"
    #run "#{sudo} monit stop workerd"
    run "kill TERM `cat #{current_path}/log/backupd.pid`"
    run "kill TERM `cat #{current_path}/log/backupd-worker.pid`"
  end

  task :start_daemons do
    #deploy.load_god_config
    # Monit don't work this way?!
    #run "sudo monit start backupd"
    #run "sudo monit start workerd"
    run "cd #{current_path} && /usr/bin/env GEM_HOME=/home/deploy DAEMON_ENV=#{stage} /usr/bin/ruby #{current_path}/bin/backupd start"
    run "cd #{current_path} && /usr/bin/env GEM_HOME=/home/deploy DAEMON_ENV=#{stage} /usr/bin/ruby #{current_path}/bin/workerd start"
  end

  task :load_god_config do
    #run "cd #{current_path} && rake DAEMON_ENV=#{fetch(:daemon_env)} god:generate"
    #run "cd #{current_path} && rake DAEMON_ENV=#{fetch(:daemon_env)} god:load"
  end
    
  desc "Installs required libraries"
  task :install_devel_libs do
    # don't die if already installed
    sudo "rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-3.noarch.rpm" rescue {}
    sudo "yum -y install erlang rabbitmq-server ncurses-devel openssl-devel"
  end
    
  task :ensure_dependencies do
    # Install missing gems
    dependencies = strategy.check!
    sudo "gem sources -a http://gems.github.com"
    other = fetch(:dependencies, {})
    other[:remote][:gem].each do |calls|
      dependencies.remote.gem(*calls)
    end
    dependencies.reject { |d| d.pass? }.each do |d|
      sudo "gem install --no-rdoc --no-ri #{$1}" if d.message =~ /gem\s\W+(\S+)'\s/
    end
  end
  
  desc "Installs required software"
  task :install_software do
  #  install_devel_libs
  end
  
  desc "Adds x bit to binaries"
  task :fix_binaries do
    run "chmod +x #{current_path}/bin/*"
  end
end

namespace :rabbitmq do
  desc "Flush active RabbitMQ queues"
  task :flush_queues do
    run "touch #{current_path}/tmp/flush_queues.txt"
  end
  
  desc "Enable active RabbitMQ queues"
  task :enable_queues do
    run "rm #{current_path}/tmp/flush_queues.txt"
  end
  
  desc "Setup RabbitMQ server - only needed once per rabbitmq server"
  task :setup do
    start_rabbitmq
    create_mq_users
    create_mq_bindings
  end
  
  desc "Creates RabbitMQ users"
  task :create_users do
    sudo "rabbitmqctl add_user backupd b4ckUrlIF3" rescue {}
    sudo "rabbitmqctl add_user bkupworker passpass" rescue {}
  end
  
  desc "Creates RabbitMQ permissions"
  task :create_bindings do
    %w[ eternos_development eternos_test eternos_staging eternos].each do |vhost|
      run "cd #{current_path} && rake VHOST=#{vhost} rabbitmq:setup_vhost"
    end
  end
  
  desc "Starts RabbitMQ server"
  task :start do
    sudo "/etc/init.d/rabbitmq start"
  end
  
  desc "Show remote RabbitMQ stats"
  task :stats do
    vhost = '/eternos'
#    vhost += "_#{stage}" unless fetch(:stage) == 'production'
    run "/usr/sbin/rabbitmqctl list_queues -p #{vhost}"
  end
end
