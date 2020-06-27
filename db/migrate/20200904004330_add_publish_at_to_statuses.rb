class AddPublishAtToStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_column :statuses, :publish_at, :datetime
    add_index :statuses, :publish_at, algorithm: :concurrently, where: 'publish_at IS NOT NULL'
  end
end
