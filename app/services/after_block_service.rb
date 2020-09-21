# frozen_string_literal: true

class AfterBlockService < BaseService
  def call(account, target_account)
    @account        = account
    @target_account = target_account

    clear_home_feed!
    clear_notifications!
    clear_conversations!
    unlink_replies!
    unlink_mentions!
  end

  private

  def clear_home_feed!
    FeedManager.instance.clear_from_home(@account, @target_account)
  end

  def clear_conversations!
    AccountConversation.where(account: @account).where('? = ANY(participant_account_ids)', @target_account.id).in_batches.destroy_all
  end

  def clear_notifications!
    Notification.where(account: @account).where(from_account: @target_account).in_batches.delete_all
  end

  def unlink_replies!
    @target_account.statuses.where(in_reply_to_account_id: @account.id)
                   .or(@account.statuses.where(in_reply_to_account_id: @target_account.id))
                   .in_batches.update_all(in_reply_to_account_id: nil)
  end

  def unlink_mentions!
    @account.mentions.where(account_id: @target_account.id)
            .or(@target_account.mentions.where(account_id: @account.id))
            .in_batches.destroy_all
  end
end
