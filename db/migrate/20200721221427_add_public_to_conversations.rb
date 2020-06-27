class AddPublicToConversations < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :conversations, :public, :boolean, default: false, null: false
    end
  end
end
