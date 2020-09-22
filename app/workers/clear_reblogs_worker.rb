# frozen_string_literal: true

class ClearReblogsWorker
  include Sidekiq::Worker

  def perform(account_id)
    FeedManager.instance.clear_reblogs_from_home(Account.find(account_id))
  rescue ActiveRecord::RecordNotFound
    true
  end
end
