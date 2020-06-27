# frozen_string_literal: true
# == Schema Information
#
# Table name: collection_pages
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)
#  uri        :string           not null
#  next       :string
#

class CollectionPage < ApplicationRecord
  belongs_to :account, inverse_of: :collection_pages, optional: true

  default_scope { order(id: :desc) }
  scope :current, -> { where(next: nil) }
end
