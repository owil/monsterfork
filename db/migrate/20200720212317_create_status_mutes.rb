class CreateStatusMutes < ActiveRecord::Migration[5.2]
  def change
    create_table :status_mutes do |t|
      t.integer :account_id, null: false, index: true
      t.bigint :status_id, null: false, index: true
    end

    add_index :status_mutes, [:account_id, :status_id], unique: true
  end
end
