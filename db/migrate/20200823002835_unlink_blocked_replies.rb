class UnlinkBlockedReplies < ActiveRecord::Migration[5.2]
  def up
    Block.find_each do |block|
      next if block.account.nil? || block.target_account.nil?

      unlink_replies!(block.account, block.target_account)
      unlink_mentions!(block.account, block.target_account)
    end
  end

  def down
    nil
  end

  private

  def unlink_replies!(account, target_account)
    target_account.statuses.where(in_reply_to_account_id: account.id)
      .or(account.statuses.where(in_reply_to_account_id: target_account.id))
      .in_batches.update_all(in_reply_to_account_id: nil)
  end

  def unlink_mentions!(account, target_account)
    account.mentions.where(account_id: target_account.id)
      .or(target_account.mentions.where(account_id: account.id))
      .in_batches.destroy_all
  end
end
