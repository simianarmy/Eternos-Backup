# twitter backup daemon.  

module BackupWorker
  class Linkedin < Base
    self.site           = 'linkedin'
    self.actions        = {
      EternosBackup::SiteData.defaultDataSet => []
    }
  end
end