#set :deploy_to, "/usr/local/eternos/#{application}"
set :deploy_to,     "/data/#{application}"
set :daemon_env, 'production'

#set :domain, "72.3.253.143" # Rackspace
set :domain, '184.73.167.220' # EngineYard
server domain, :app
