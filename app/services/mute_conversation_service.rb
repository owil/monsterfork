# frozen_string_literal: true

class MuteConversationService < BaseService
  def call(account, conversation, hidden: false)
    return if account.blank? || conversation.blank?

    account.mute_conversation!(conversation, hidden: hidden)
    MuteConversationWorker.perform_async(account.id, conversation.id) if hidden
  end
end
