# frozen_string_literal: true
# == Schema Information
#
# Table name: status_mutes
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)        not null
#  status_id  :bigint(8)        not null
#

class StatusMute < ApplicationRecord
  include Cacheable

  validates :account_id, uniqueness: { scope: :status_id }

  belongs_to :account, inverse_of: :status_mutes
  belongs_to :status, inverse_of: :mutes

  cache_associated :account, :status
end
