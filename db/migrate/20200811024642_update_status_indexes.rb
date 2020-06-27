class UpdateStatusIndexes < ActiveRecord::Migration[5.2]
  def up
    safety_assured do
      add_index :statuses, ["id", "account_id"], name: "index_statuses_local", order: { id: :desc }, where: "((published = TRUE) AND (local = TRUE OR (uri IS NULL)) AND (deleted_at IS NULL) AND (visibility = 0) AND (reblog_of_id IS NULL) AND ((reply = FALSE) OR (in_reply_to_account_id = account_id)))"
      add_index :statuses, ["id", "account_id"], name: "index_statuses_public", order: { id: :desc }, where: "((published = TRUE) AND (deleted_at IS NULL) AND (visibility = 0) AND (reblog_of_id IS NULL) AND ((reply = FALSE) OR (in_reply_to_account_id = account_id)))"
      add_index :statuses, ["id", "account_id"], name: "index_statuses_local_reblogs", where: "(((local = TRUE) OR (uri IS NULL)) AND (statuses.reblog_of_id IS NOT NULL))"

      remove_index :statuses, name: "index_statuses_local_20190824"
      remove_index :statuses, name: "index_statuses_public_20200119"
    end
  end

  def down
    safety_assured do
      add_index :statuses, ["id", "account_id"], name: "index_statuses_local_20190824", order: { id: :desc }, where: "((local OR (uri IS NULL)) AND (deleted_at IS NULL) AND (visibility = 0) AND (reblog_of_id IS NULL) AND ((NOT reply) OR (in_reply_to_account_id = account_id)))"
      add_index :statuses, ["id", "account_id"], name: "index_statuses_public_20200119", order: { id: :desc }, where: "((deleted_at IS NULL) AND (visibility = 0) AND (reblog_of_id IS NULL) AND ((NOT reply) OR (in_reply_to_account_id = account_id)))"

      remove_index :statuses, name: "index_statuses_local"
      remove_index :statuses, name: "index_statuses_local_reblogs"
      remove_index :statuses, name: "index_statuses_public"
    end
  end
end
