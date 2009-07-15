set :deploy_to, "/usr/local/eternos/#{application}"

set :daemon_env, 'production'

set :domain, "72.3.253.143"
server domain, :app
