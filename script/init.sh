# Server startup script to start required non-root application services

APP_DIR=/usr/local/eternos/backupd/current
GOD=/opt/ruby-enterprise-1.8.6-20090610/bin/god
RAKE=/opt/ruby-enterprise-1.8.6-20090610/bin/rake
export DAEMON_ENV=production

echo "cd $APP_DIR && $RAKE god:load"
cd $APP_DIR && $RAKE god:load
echo "cd $APP_DIR && $GOD monitor eternos-backup_production"
cd $APP_DIR && $GOD monitor eternos-backup_production
