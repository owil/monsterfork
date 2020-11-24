class AddNoVerifyAuthToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :accounts, :no_verify_auth, :boolean, null: false, default: false
    end
  end
end
