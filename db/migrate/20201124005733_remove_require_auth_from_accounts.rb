class RemoveRequireAuthFromAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      remove_column :accounts, :require_auth, :boolean, null: false, default: false
    end
  end
end
