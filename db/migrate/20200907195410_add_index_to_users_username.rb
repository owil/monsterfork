class AddIndexToUsersUsername < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :users, :username, unique: true, algorithm: :concurrently
    add_index :users, 'lower(username)', unique: true, algorithm: :concurrently, name: 'index_on_users_username_lowercase'
  end
end
