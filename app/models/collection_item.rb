# frozen_string_literal: true
# == Schema Information
#
# Table name: collection_items
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)
#  uri        :string           not null
#  processed  :boolean          default(FALSE), not null
#  retries    :integer          default(0), not null
#

class CollectionItem < ApplicationRecord
  belongs_to :account, inverse_of: :collection_items, optional: true

  default_scope { order(id: :desc) }
  scope :unprocessed, -> { where(processed: false) }
  scope :joins_on_collection_pages, -> { joins('LEFT OUTER JOIN collection_pages ON collection_pages.account_id = collection_items.account_id') }
  scope :inactive, -> { joins_on_collection_pages.where('collection_pages.account_id IS NULL') }
  scope :active, -> { joins_on_collection_pages.where('collection_pages.account_id IS NOT NULL') }
end
