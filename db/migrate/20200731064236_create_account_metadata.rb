class CreateAccountMetadata < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    create_table :account_metadata do |t|
      t.references :account, null: false, unique: true, foreign_key: { on_delete: :cascade }
      t.jsonb :fields, null: false, default: {}
    end
  end
end
