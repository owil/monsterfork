# frozen_string_literal: true

class PrecomputeFeedService < BaseService
  def call(account)
    Redis.current.del("feed:home:#{account.id}")
    FeedManager.instance.populate_feed(account)
    FeedManager.instance.populate_direct_feed(account)
  ensure
    Redis.current.del("account:#{account.id}:regeneration")
  end
end
