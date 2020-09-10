# frozen_string_literal: true

class AccountDefederationWorker
  include Sidekiq::Worker

  def perform(account_id, domains)
    DefederateAccountService.new.call(Account.find(account_id), domains)
  rescue ActiveRecord::RecordNotFound
    true
  end
end
