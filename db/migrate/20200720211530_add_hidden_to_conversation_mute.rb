class AddHiddenToConversationMute < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :conversation_mutes, :hidden, :boolean, default: false, null: false
    end
  end
end
