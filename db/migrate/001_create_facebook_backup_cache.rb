class CreateFacebookBackupCache < ActiveRecord::Migration
  def self.up
    create_table :fb_backup_cache do |t|
      t.integer :user_id, :target_id
    end
  end

  def self.down
    drop_table :fb_backup_cache
  end
end