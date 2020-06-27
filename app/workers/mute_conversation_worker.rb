# frozen_string_literal: true

class MuteConversationWorker
  include Sidekiq::Worker

  def perform(account_id, conversation_id)
    FeedManager.instance.unpush_conversation(Account.find(account_id), Conversation.find(conversation_id))
  rescue ActiveRecord::RecordNotFound
    true
  end
end
