# frozen_string_literal: true

class ActivityPub::RawDistributionWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'push'

  def perform(json, source_account_id, exclude_inboxes = [], options = {})
    @options = options.with_indifferent_access
    @account = Account.find(source_account_id)

    ActivityPub::DeliveryWorker.push_bulk(inboxes - exclude_inboxes) do |inbox_url|
      [json, @account.id, inbox_url]
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def inboxes
    @inboxes ||= (@options[:all_servers] || @account.id == -99 ? Account.remote.without_suspended.inboxes : @account.followers.inboxes)
  end
end
