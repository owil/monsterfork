# frozen_string_literal: true

class DistributionWorker
  include Sidekiq::Worker

  def perform(status_id, only_to_self = false)
    RedisLock.acquire(redis: Redis.current, key: "distribute:#{status_id}") do |lock|
      if lock.acquired?
        status = Status.find(status_id)
        FanOutOnWriteService.new.call(status, only_to_self: !status.published? || only_to_self || !status.notify?)
      else
        raise Mastodon::RaceConditionError
      end
    end
  rescue ActiveRecord::RecordNotFound
    true
  end
end
