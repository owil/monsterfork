class CreateInlineMediaAttachments < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    create_table :inline_media_attachments do |t|
      t.references :status, index: { algorithm: :concurrently }, foreign_key: { on_delete: :cascade }
      t.references :media_attachment, index: { algorithm: :concurrently }, foreign_key: { on_delete: :cascade }
    end

    add_index :inline_media_attachments, [:status_id, :media_attachment_id], unique: true, algorithm: :concurrently, name: 'uniq_index_on_status_and_attachment'
  end
end
