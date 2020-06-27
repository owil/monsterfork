class AddUnpublishedIndexToStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :statuses, [:account_id, :id], where: '(deleted_at IS NULL) AND (published = FALSE)', order: { id: :desc }, algorithm: :concurrently, name: :index_unpublished_statuses
  end
end
