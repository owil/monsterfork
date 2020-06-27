# frozen_string_literal: true
# == Schema Information
#
# Table name: account_metadata
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)        not null
#  fields     :jsonb            not null
#

class AccountMetadata < ApplicationRecord
  include Cacheable

  belongs_to :account, inverse_of: :metadata
  cache_associated :account

  def fields
    self[:fields].presence || {}
  end

  def fields_json
    fields.select { |name, _| name.start_with?('custom:') }
          .map do |name, value|
            {
              '@context': {
                schema: 'http://schema.org/',
                name: 'schema:name',
                value: 'schema:value',
              },
              type: 'PropertyValue',
              name: name,
              value: value.is_a?(Array) ? value.join("\r\n") : value,
            }
          end
  end

  def cached_fields_json
    Rails.cache.fetch("custom_metadata:#{account_id}", expires_in: 1.hour) do
      fields_json
    end
  end

  class << self
    def create_or_update(fields)
      create(fields).presence || update(fields)
    end

    def create_or_update!(fields)
      create(fields).presence || update!(fields)
    end
  end
end
