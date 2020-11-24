class AddAllowAnonymousToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :allow_anonymous, :boolean, null: false, default: false
  end
end
