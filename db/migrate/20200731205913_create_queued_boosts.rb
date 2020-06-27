class CreateQueuedBoosts < ActiveRecord::Migration[5.2]
  def change
    create_table :queued_boosts do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :status, null: false, foreign_key: { on_delete: :cascade }
    end

    add_index :queued_boosts, [:account_id, :status_id], unique: true
  end
end
