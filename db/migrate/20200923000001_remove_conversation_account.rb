class RemoveConversationAccount < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      remove_column :conversations, :account_id
    end
  end
end
