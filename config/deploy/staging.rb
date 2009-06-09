#set :deploy_to, "/svc/backupd" # defaults to "/u/apps/#{application}"
#set :user, ""            # defaults to the currently logged in user
set :daemon_env, 'staging'

set :domain, 'example.com'
server domain
