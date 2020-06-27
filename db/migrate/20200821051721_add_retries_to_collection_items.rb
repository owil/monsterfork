class AddRetriesToCollectionItems < ActiveRecord::Migration[5.2]
  def change
    add_column :collection_items, :retries, :integer, limit: 1, default: 0, null: false
  end
end
