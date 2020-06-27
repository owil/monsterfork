# frozen_string_literal: true

class Scheduler::PublishStatusScheduler
  include Sidekiq::Worker

  sidekiq_options lock: :until_executed, retry: 0

  def perform
    Status.ready_to_publish.find_each { |status| PublishStatusService.new.call(status) }
  end
end
