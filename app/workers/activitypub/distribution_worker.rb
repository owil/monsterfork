# frozen_string_literal: true

class ActivityPub::DistributionWorker
  include Sidekiq::Worker
  include Payloadable

  sidekiq_options queue: 'push'

  def perform(status_id, options = {})
    @options = options.with_indifferent_access
    @status  = Status.find(status_id)
    @account = @status.account
    @payload = {}

    return if skip_distribution?

    ActivityPub::DeliveryWorker.push_bulk(inboxes) do |inbox_url|
      [payload(inbox_url), @account.id, inbox_url, { synchronize_followers: !@status.distributable? }]
    end

    relay! if relayable?
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def skip_distribution?
    !@status.published? || @status.direct_visibility? || @status.limited_visibility?
  end

  def relayable?
    @status.public_visibility? && !@account.private?
  end

  def inboxes
    return Account.remote.without_suspended.inboxes if @options[:all_servers] || @account.id == -99

    # Deliver the status to all followers.
    # If the status is a reply to another local status, also forward it to that
    # status' authors' followers.
    @inboxes ||= if @status.reply? && @status.thread&.account&.local? && @status.distributable?
                   @account.followers.or(@status.thread.account.followers).inboxes
                 else
                   @account.followers.inboxes
                 end
  end

  def payload(inbox_url)
    domain = Addressable::URI.parse(inbox_url).normalized_host
    @payload[domain] ||= Oj.dump(serialize_payload(ActivityPub::ActivityPresenter.from_status(@status, domain, update: true), ActivityPub::ActivitySerializer, signer: @account, domain: domain))
  end

  def relay!
    ActivityPub::DeliveryWorker.push_bulk(Relay.enabled.pluck(:inbox_url)) do |inbox_url|
      [payload(inbox_url), @account.id, inbox_url]
    end
  end
end
