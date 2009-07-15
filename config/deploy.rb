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

# Record our dependencies
depend :remote, :gem, "rubigen", ">= 1.5.2"
depend :remote, :gem, "eventmachine", ">= 0.12.8"
depend :remote, :gem, "tmm1-amqp", ">= 0.6.0"
depend :remote, :gem, "kennethkalmer-daemon-kit", ">= 0.1.7.9"
depend :remote, :gem, 'httpclient', ">= 2.1.5.1"
depend :remote, :gem, 'cpowell-SyslogLogger', ">= 1.4.0"
depend :remote, :gem, 'mislav-hanna', ">= 0.1.7"
depend :remote, :gem, 'simianarmy-ruote-external-workitem-rails', ">= 0.2.0"
depend :remote, :directory, "/usr/local/src"

# Specify erlang distribution name 
# set :erlang
# Hook into capistrano's events
before "deploy:update_code", "deploy:check"
after "deploy:setup", "deploy:install_software"

# Create some tasks related to deployment
namespace :deploy do

  desc "Get the current revision of the deployed code"
  task :get_current_version do
    run "cat #{current_path}/REVISION" do |ch, stream, out|
      puts "Current revision: " + out.chomp
    end
  end
  
  desc "Installs required libraries"
  task :install_devel_libs do
    sudo "yum -y install ncurses-devel openssl-devel"
  end
  
  desc "Install erlang language" 
  task :install_erlang do
    erlang = fetch(:erlang, 'otp_src_R13B01')
    run <<-AMQP
      cd /usr/local/src; \
      if [ ! -e "#{erlang}.tar.gz" ]; then \
        wget http://erlang.org/download/#{erlang}.tar.gz; \
        tar -zxvf #{erlang}.tar.gz; \
      fi; \
      cd #{erlang}; ./configure; make;
    AMQP
    run "cd /usr/local/src/#{erlang} && #{sudo} make install"
  end
  
  desc "Installs AMQP server software"
  task :build_amqp do
     install_erlang
  end
  
  desc "Installs ruote engine"
  task :build_ruote do
    run <<-RUOTE
      if [ ! -e "/usr/local/src/ruote/pkg/*.gem" ]; then \
        cd /usr/local/src; git clone git://github.com/jmettraux/ruote.git; cd ruote; rake gem; \
      fi
    RUOTE
    sudo "gem install --no-rdoc --no-ri /usr/local/src/ruote/pkg/*.gem"
  end
  
  desc "Installs required software"
  task :install_software do
    install_devel_libs 
    build_amqp
    build_ruote
    
    # Install missing gems
    dependencies = strategy.check!
    
    other = fetch(:dependencies, {})
    other[:remote][:gem].each do |calls|
      dependencies.remote.gem(*calls)
    end
    dependencies.reject { |d| d.pass? }.each do |d|
      d.message =~ /gem\s\W+(\S+)'\s/
      sudo "gem install --no-rdoc --no-ri #{$1}"
    end
  end
end
