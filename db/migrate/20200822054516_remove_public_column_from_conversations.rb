class RemovePublicColumnFromConversations < ActiveRecord::Migration[5.2]
  def change
    def safety_assured
      remove_column :conversations, :public
    end
  end
end
