# frozen_string_literal: true
class ActivityPub::ProcessCollectionItemsWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  def perform
    return if Sidekiq::Stats.new.workers_size > 3

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        account_id = random_unprocessed_account_id
        ActivityPub::ProcessCollectionItemsForAccountWorker.perform_async(account_id) if account_id.present?
      end
    end
  end

  private

  def random_unprocessed_account_id
    CollectionItem.unprocessed.pluck(:account_id).sample
  end

  def lock_options
    { redis: Redis.current, key: 'process_collection_items' }
  end
end
