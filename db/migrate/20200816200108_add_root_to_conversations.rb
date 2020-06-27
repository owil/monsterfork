class AddRootToConversations < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :conversations, :root, :string, index: true
    end
  end
end
