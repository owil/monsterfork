class CreateAccountDomainPermissions < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    create_table :account_domain_permissions do |t|
      t.references :account, null: false, index: { algorithm: :concurrently }, foreign_key: { on_delete: :cascade }
      t.string :domain, null: false, default: '', index: { algorithm: :concurrently }
      t.integer :visibility, null: false, default: 0, index: { algorithm: :concurrently }
    end

    add_index :account_domain_permissions, [:account_id, :domain], unique: true, algorithm: :concurrently
  end
end
