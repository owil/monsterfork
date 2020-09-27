class DropConversationsPublic < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      remove_column :conversations, :public
    end
  end
end
