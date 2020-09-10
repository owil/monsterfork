# frozen_string_literal: true

class DefederateAccountService < BaseService
  include Payloadable

  def call(account, domains)
    @account = account
    @domains = domains

    return if account.blank? || !account.local? || domains.blank?

    distribute_delete_actor!
  end

  private

  def distribute_delete_actor!
    ActivityPub::DeliveryWorker.push_bulk(delivery_inboxes) do |inbox_url|
      [delete_actor_json, @account.id, inbox_url]
    end

    ActivityPub::LowPriorityDeliveryWorker.push_bulk(low_priority_delivery_inboxes) do |inbox_url|
      [delete_actor_json, @account.id, inbox_url]
    end
  end

  def delete_actor_json
    @delete_actor_json ||= Oj.dump(serialize_payload(@account, ActivityPub::DeleteActorSerializer, signer: @account))
  end

  def delivery_inboxes
    @delivery_inboxes ||= @account.followers.where(domain: @domains).inboxes
  end

  def low_priority_delivery_inboxes
    Account.where(domain: @domains).inboxes - delivery_inboxes
  end
end
