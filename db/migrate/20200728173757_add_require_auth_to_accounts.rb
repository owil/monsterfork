class AddRequireAuthToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :accounts, :require_auth, :boolean, default: false, null: false
    end
  end
end
