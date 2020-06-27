# frozen_string_literal: true
# == Schema Information
#
# Table name: inline_media_attachments
#
#  id                  :bigint(8)        not null, primary key
#  status_id           :bigint(8)
#  media_attachment_id :bigint(8)
#

class InlineMediaAttachment < ApplicationRecord
  include Cacheable

  validates :status_id, uniqueness: { scope: :media_attachment_id }

  belongs_to :status, inverse_of: :inlined_attachments
  belongs_to :media_attachment, inverse_of: :inlines

  cache_associated :status, :media_attachment
end
