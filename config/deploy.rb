# Modified capistrano recipe, based on the standard 'deploy' recipe
# provided by capistrano but without the Rails-specific dependencies

set :stages, %w(staging production)
set :default_stage, "staging"
require "capistrano/ext/multistage"

# Set some globals
default_run_options[:pty] = true
set :application, "backupd"

# Deployment
set :user, 'mmauger'
#set :runner, 'mmauger'

# Get repo configuration
set :scm, 'subversion'
set :svn_user, ENV['svn_user'] || "marc"
set :svn_password, ENV['svn_password'] || Proc.new { Capistrano::CLI.password_prompt('SVN Password: ') }
set :repository,
  Proc.new { "--username #{svn_user} " +
             "--password #{svn_password} " +
             "--no-auth-cache " + 
             "https://eternos.unfuddle.com/svn/eternos_system/trunk" }
set :deploy_via, :remote_cache

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

# List backup workers that should be running along with the main 
# backup daemon
set :backup_workers, %w{ emaild facebookd rssd twitterd }

# Record our dependencies
depend :remote, :gem, "rgrove-larch", ">= 1.0.1.1"
depend :remote, :gem, "rcov", ">= 0.8.1.2"
depend :remote, :gem, "rubigen", ">= 1.5.2"
depend :remote, :gem, "eventmachine", ">= 0.12.8"
# should be pulled in by simianarmy-ruote-amqp
#depend :remote, :gem, "tmm1-amqp", ">= 0.6.4"
depend :remote, :gem, "kennethkalmer-daemon-kit", ">= 0.1.7.9"
depend :remote, :gem, 'httpclient', ">= 2.1.5.1"
depend :remote, :gem, 'cpowell-SyslogLogger', ">= 1.4.0"
depend :remote, :gem, 'mislav-hanna', ">= 0.1.7"
depend :remote, :gem, "simianarmy-ruote-amqp", ">= 0.9.21"
depend :remote, :gem, 'ruote-external-workitem-rails', ">= 0.2.0"
depend :remote, :gem, 'pauldix-feedzirra', ">= 0.0.17"
depend :remote, :gem, 'god', '0.7.13'
depend :remote, :gem, 'SystemTimer', '1.1.1'
depend :remote, :gem, 'twitter', '>= 0.6.15'
depend :remote, :gem, 'moomerman-twitter_oauth', :lib => 'twitter_oauth'
depend :remote, :gem, 'mysqlplus'
depend :remote, :directory, "/usr/local/src"

# Specify erlang distribution name 
# set :erlang
# Hook into capistrano's events

before "deploy:update_code", "deploy:stop_daemons"
before "deploy:setup", "deploy:install_software"
after "deploy:symlink", "deploy:fix_binaries"

# Create some tasks related to deployment
namespace :deploy do

  desc "Get the current revision of the deployed code"
  task :get_current_version do
    run "cat #{current_path}/REVISION" do |ch, stream, out|
      puts "Current revision: " + out.chomp
    end
  end
  
  task :stop_daemons do
    run "god stop eternos-backup_#{stage}"
  end
  
  task :start do
    load_god_config
    run "god monitor eternos-backup_#{stage}"
  end
    
  task :load_god_config do
    run "god"
    run "cd #{current_path} && rake DAEMON_ENV=#{fetch(:daemon_env)} god:generate"
    run "cd #{current_path} && rake DAEMON_ENV=#{fetch(:daemon_env)} god:load"
  end
    
  desc "Installs required libraries"
  task :install_devel_libs do
    # don't die if already installed
    sudo "rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-3.noarch.rpm" rescue {}
    sudo "yum -y install erlang rabbitmq-server ncurses-devel openssl-devel"
  end
    
  desc "Setup RabbitMQ server - only needed once per rabbitmq server"
  task :setup_rabbitmq do
    start_rabbitmq
    create_mq_users
    create_mq_bindings
  end
  
  desc "Creates RabbitMQ users"
  task :create_mq_users do
    sudo "rabbitmqctl add_user backupd b4ckUrlIF3"
    sudo "rabbitmqctl add_user bkupworker passpass"
  end
  
  desc "Creates RabbitMQ permissions"
  task :create_mq_bindings do
    %w[ eternos_development eternos_test eternos_staging eternos].each do |vhost|
      run "cd #{current_path} && rake VHOST=#{vhost} rabbitmq:setup_vhost"
    end
  end
  
  desc "Starts RabbitMQ server"
  task :start_rabbitmq do
    sudo "/usr/sbin/rabbitmq-server -detached"
  end
  
  desc "Show remote RabbitMQ stats"
  task :rabbitmq_stats do
    sudo "/usr/sbin/rabbitmqctl list_queues -p /eternos"
  end
  
  desc "Installs ruote engine"
  task :build_ruote do
    run <<-RUOTE
      if [ ! -e "/usr/local/src/ruote/pkg/*.gem" ]; then \
        cd /usr/local/src; \
        if [ ! -d "/usr/local/src/ruote" ]; then \
          git clone git://github.com/jmettraux/ruote.git; cd ruote; rake gem; \
        fi
      fi
    RUOTE
    sudo "gem install --no-rdoc --no-ri /usr/local/src/ruote/pkg/*.gem"
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
    build_ruote
    ensure_dependencies
    install_devel_libs
  end
  
  desc "Adds x bit to binaries"
  task :fix_binaries do
    run "chmod +x #{current_path}/bin/*"
  end
end
