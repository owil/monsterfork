class CreateDestructingStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    create_table :destructing_statuses do |t|
      t.references :status, null: false, unique: true, foreign_key: { on_delete: :cascade }
      t.datetime :after, null: false, index: { algorithm: :concurrently }
      t.boolean :defederate_only, null: false, default: false
    end
  end
end
