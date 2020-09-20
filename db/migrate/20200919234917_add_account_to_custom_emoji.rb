class AddAccountToCustomEmoji < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_reference :custom_emojis, :account, foreign_key: { on_delete: :nullify }, index: true
    end
  end
end
