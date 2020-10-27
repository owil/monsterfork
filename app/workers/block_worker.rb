# frozen_string_literal: true

class BlockWorker
  include Sidekiq::Worker

  def perform(account_id, target_account_id, defederate: true)
    AfterBlockService.new.call(
      Account.find(account_id),
      Account.find(target_account_id),
      defederate: defederate
    )
  end
end
