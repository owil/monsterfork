# frozen_string_literal: true

# Obsolete but kept around to make sure existing jobs do not fail after upgrade.
# Should be removed in a subsequent release.

class ActivityPub::ReplyDistributionWorker
  include Sidekiq::Worker
  include Payloadable

  sidekiq_options queue: 'push'

  def perform(status_id, options = {})
    @options = options.with_indifferent_access
    @status  = Status.find(status_id)
    @account = @status.thread&.account
    @payload = {}

    return unless @account.present? && @status.distributable?

    ActivityPub::DeliveryWorker.push_bulk(inboxes) do |inbox_url|
      [payload(inbox_url), @status.account_id, inbox_url]
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def inboxes
    @inboxes ||= (@options[:all_servers] || @account.id == -99 ? Account.remote.without_suspended.inboxes : @account.followers.inboxes)
  end

  def payload(inbox_url)
    domain = Addressable::URI.parse(inbox_url).normalized_host
    @payload[domain] ||= Oj.dump(serialize_payload(ActivityPub::ActivityPresenter.from_status(@status, domain, update: true), ActivityPub::ActivitySerializer, signer: @status.account, domain: domain))
  end
end
