# frozen_string_literal: true

class FetchReplyWorker
  include Sidekiq::Worker
  include ExponentialBackoff

  sidekiq_options queue: 'pull', retry: 3

  def perform(child_url, account_id = nil)
    account = account_id.blank? ? nil : Account.find_by(id: account_id)
    on_behalf_of = account.blank? ? nil : account.followers.local.random.first

    FetchRemoteStatusService.new.call(child_url, nil, on_behalf_of)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
