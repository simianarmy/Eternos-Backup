#set :deploy_to, "/svc/backupd" # defaults to "/u/apps/#{application}"
#set :user, ""            # defaults to the currently logged in user
set :deploy_to, "/usr/local/eternos/#{application}_staging"
set :daemon_env, 'staging'

set :domain, "72.3.253.143"
server domain, :app
