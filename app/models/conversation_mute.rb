# frozen_string_literal: true
# == Schema Information
#
# Table name: conversation_mutes
#
#  id              :bigint(8)        not null, primary key
#  conversation_id :bigint(8)        not null
#  account_id      :bigint(8)        not null
#  hidden          :boolean          default(FALSE), not null
#

class ConversationMute < ApplicationRecord
  belongs_to :account, inverse_of: :conversation_mutes
  belongs_to :conversation, inverse_of: :mutes
end
