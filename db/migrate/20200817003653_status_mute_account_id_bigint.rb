class StatusMuteAccountIdBigint < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      change_column :status_mutes, :account_id, :bigint, null: false
    end
  end
end
