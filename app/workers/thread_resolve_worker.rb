# frozen_string_literal: true

class ThreadResolveWorker
  include Sidekiq::Worker
  include ExponentialBackoff

  sidekiq_options queue: 'pull', retry: 3

  def perform(child_status_id, parent_url, on_behalf_of = nil)
    child_status  = Status.find(child_status_id)
    on_behalf_of  = child_status.account.followers.local.random.first if on_behalf_of.nil? && !child_status.distributable?
    parent_status = FetchRemoteStatusService.new.call(parent_url, nil, on_behalf_of)

    return if parent_status.nil?

    child_status.thread = parent_status
    child_status.save!
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    nil
  end
end
