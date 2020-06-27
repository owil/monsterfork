class BackfillAccountMetadata < ActiveRecord::Migration[5.2]
  def up
    safety_assured do
      execute("INSERT INTO account_metadata (account_id) SELECT id FROM accounts WHERE domain IS NULL OR domain = ''")
    end
  end

  def down
    true
  end
end
