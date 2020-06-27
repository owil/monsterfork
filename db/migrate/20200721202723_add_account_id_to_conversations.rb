class AddAccountIdToConversations < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_reference :conversations, :account, foreign_key: true, index: {algorithm: :concurrently}
    end
  end
end
