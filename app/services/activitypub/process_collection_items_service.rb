# frozen_string_literal: true

class ActivityPub::ProcessCollectionItemsService < BaseService
  def call(account_id, on_behalf_of)
    RedisLock.acquire(lock_options(account_id)) do |lock|
      if lock.acquired?
        CollectionItem.unprocessed.where(account_id: account_id).find_each do |item|
          # Avoid failing servers holding up the rest of the queue.
          next if item.retries.positive? && rand(3).positive?

          begin
            FetchRemoteStatusService.new.call(item.uri, nil, on_behalf_of)
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
            nil
          rescue HTTP::TimeoutError
            item.increment!(:retries)
          end

          item.update!(processed: true) if item.retries.zero? || item.retries > 4
        end
      end
    end
  end

  private

  def lock_options(account_id)
    { redis: Redis.current, key: "process_collection_items:#{account_id}" }
  end
end
