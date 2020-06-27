# frozen_string_literal: true
class ActivityPub::ProcessCollectionItemsForAccountWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 3

  def perform(account_id)
    @account_id = account_id
    on_behalf_of = nil

    if account_id.present?
      account = Account.find(account_id)
      on_behalf_of = account.followers.local.random.first
    end

    ActivityPub::ProcessCollectionItemsService.new.call(account_id, on_behalf_of)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
