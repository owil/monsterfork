# frozen_string_literal: true

class DomainDefederationWorker
  include Sidekiq::Worker

  def perform(domains)
    DefederateDomainService.new.call(domains)
  rescue ActiveRecord::RecordNotFound
    true
  end
end
