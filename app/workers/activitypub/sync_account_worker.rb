# frozen_string_literal: true
class ActivityPub::SyncAccountWorker
  include Sidekiq::Worker
  include ExponentialBackoff

  sidekiq_options queue: 'pull', retry: 5

  def perform(account_id, every_page = false, skip_cooldown = false)
    @account = Account.find(account_id)
    return if @account.local?

    @from_migrated_account = @account.moved_to_account&.local?
    return unless @from_migrated_account || @account.followers.local.exists?

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        fetch_collection_items(every_page, skip_cooldown)
      elsif @from_migrated_account
        # Cause a retry so server-to-server migrations can complete.
        raise Mastodon::RaceConditionError
      end
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  private

  def lock_options
    { redis: Redis.current, key: "account_sync:#{@account.id}" }
  end

  # Limits for an account moving to this server.
  def limits_migrated
    {
      page_limit: 2_000,
      item_limit: 40_000,
      look_ahead: true,
    }
  end

  # Limits for an account someone locally follows.
  def limits_followed
    {
      page_limit: 25,
      item_limit: 500,
      look_ahead: @account.last_synced_at.blank?,
    }
  end

  def fetch_collection_items(every_page, skip_cooldown)
    opts = @from_migrated_account && every_page ? limits_migrated : limits_followed
    opts.merge!({ every_page: every_page, skip_cooldown: skip_cooldown })
    ActivityPub::FetchCollectionItemsService.new.call(@account.outbox_url, @account, **opts)
    @account.update(last_synced_at: Time.now.utc)
  end
end
