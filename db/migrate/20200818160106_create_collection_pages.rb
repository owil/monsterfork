class CreateCollectionPages < ActiveRecord::Migration[5.2]
  def change
    create_table :collection_pages do |t|
      t.references :account, index: true, foreign_key: { on_delete: :cascade }
      t.string :uri, null: false, index: { unique: true }
      t.string :next
    end

    add_index :collection_pages, :id, name: 'unprocessed_collection_page_ids', where: 'next IS NULL'
    add_index :collection_pages, :account_id, name: 'unprocessed_collection_page_account_ids', where: 'next IS NULL'
    add_index :collection_pages, :uri, name: 'unprocessed_collection_pages_uris', where: 'next IS NULL'
  end
end
