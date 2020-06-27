class AddExpiresAtToStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_column :statuses, :expires_at, :datetime
    add_index :statuses, :expires_at, algorithm: :concurrently, where: 'expires_at IS NOT NULL'
  end
end
