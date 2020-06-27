class AddShowUnlistedToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :accounts, :show_unlisted, :boolean, null: false, default: true
    end
  end
end
