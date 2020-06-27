# frozen_string_literal: true

class LinkCrawlWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  def perform(status_id)
    status = Status.find(status_id)
    FetchLinkCardService.new.call(status) if status.published?
  rescue ActiveRecord::RecordNotFound
    true
  end
end
