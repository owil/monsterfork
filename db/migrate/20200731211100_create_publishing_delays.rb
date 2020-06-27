class CreatePublishingDelays < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    create_table :publishing_delays do |t|
      t.references :status, null: false, unique: true, foreign_key: { on_delete: :cascade }
      t.datetime :after, index: { algorithm: :concurrently }
    end
  end
end
