# frozen_string_literal: true

class MuteConversationService < BaseService
  def call(account, conversation)
    return if account.blank? || conversation.blank?

    account.mute_conversation!(conversation)
    MuteConversationWorker.perform_async(account.id, conversation.id) unless account.id == conversation.account_id
  end
end
