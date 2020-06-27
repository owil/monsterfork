class AddAccountsToPublishingDelays < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_reference :publishing_delays, :account, null: false, foreign_key: { on_delete: :cascade }, index: { algorithm: :concurrently }
    end
  end
end
