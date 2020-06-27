class CreateCollectionItems < ActiveRecord::Migration[5.2]
  def change
    create_table :collection_items do |t|
      t.references :account, index: true, foreign_key: { on_delete: :cascade }
      t.string :uri, null: false, index: { unique: true }
      t.boolean :processed, null: false, default: false
    end

    add_index :collection_items, :id, name: 'unprocessed_collection_item_ids', where: 'processed = FALSE', order: { id: :desc }
    add_index :collection_items, :account_id, name: 'unprocessed_collection_item_account_ids', where: 'processed = FALSE'
  end
end
