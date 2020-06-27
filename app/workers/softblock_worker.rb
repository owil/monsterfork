# frozen_string_literal: true

class SoftblockWorker
  include Sidekiq::Worker

  def perform(account_id, target_account_id)
    account        = Account.find(account_id)
    target_account = Account.find(target_account_id)

    BlockService.new.call(account, target_account, softblock: true)
    sleep 1
    UnblockService.new.call(account, target_account)
  rescue ActiveRecord::RecordNotFound
    true
  end
end
