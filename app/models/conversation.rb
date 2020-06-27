# frozen_string_literal: true
# == Schema Information
#
# Table name: conversations
#
#  id         :bigint(8)        not null, primary key
#  uri        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint(8)
#  public     :boolean          default(FALSE), not null
#  root       :string
#

class Conversation < ApplicationRecord
  validates :uri, uniqueness: true, if: :uri?

  has_many :statuses
  has_many :mutes, class_name: 'ConversationMute', inverse_of: :conversation, dependent: :destroy
  belongs_to :account, inverse_of: :threads, optional: true

  def local?
    uri.nil?
  end
end
