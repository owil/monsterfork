class AddIndexOnStatusesVisibility < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :statuses, :visibility, where: 'deleted_at IS NULL', algorithm: :concurrently, name: :index_statuses_on_visibility
  end
end
