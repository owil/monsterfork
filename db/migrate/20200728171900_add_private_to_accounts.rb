class AddPrivateToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :accounts, :private, :boolean, default: false, null: false
    end
  end
end
