# frozen_string_literal: true

class AfterBlockService < BaseService
  def call(account, target_account)
    @account        = account
    @target_account = target_account

    clear_home_feed!
    clear_notifications!
    clear_conversations!

    defederate_interactions!
    unlink_interactions!
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

  def unlink_interactions!
    @target_account.statuses.where(in_reply_to_account_id: @account.id).in_batches.update_all(in_reply_to_account_id: nil)
    @target_account.mentions.where(account_id: @account.id).in_batches.destroy_all
  end

  def defederate_interactions!
    defederate_statuses!(@account.statuses.where(in_reply_to_account_id: @target_account.id))
    defederate_statuses!(@account.statuses.joins(:mentions).where(mentions: { account_id: @target_account.id }))
    defederate_statuses!(@account.statuses.joins(:reblog).where(reblogs_statuses: { account_id: @target_account.id }))
    defederate_favourites!
  end

  def defederate_statuses!(statuses)
    statuses.find_each { |status| RemovalWorker.perform_async(status.id, unpublish: true, blocking: @target_account.id) }
  end

  def defederate_favourites!
    favourites = @account.favourites.joins(:status).where(statuses: { account_id: @target_account.id })
    favourites.pluck(:status_id).each do |status_id|
      UnfavouriteWorker.perform_async(@account.id, status_id)
    end
  end
end
