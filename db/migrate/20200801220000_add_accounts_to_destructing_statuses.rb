class AddAccountsToDestructingStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_reference :destructing_statuses, :account, null: false, foreign_key: { on_delete: :cascade }, index: { algorithm: :concurrently }
    end
  end
end
