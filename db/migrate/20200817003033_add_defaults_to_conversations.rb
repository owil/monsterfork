class AddDefaultsToConversations < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      change_column :conversations, :account_id, :bigint, default: nil
      change_column :conversations, :root, :string, default: nil
    end
  end
end
