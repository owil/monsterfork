class AddAllowAnonymousToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :accounts, :allow_anonymous, :boolean, null: false, default: false
    end
  end
end
