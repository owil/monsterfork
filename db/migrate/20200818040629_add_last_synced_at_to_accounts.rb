class AddLastSyncedAtToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :last_synced_at, :datetime
  end
end
