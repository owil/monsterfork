# frozen_string_literal: true
# == Schema Information
#
# Table name: status_domain_permissions
#
#  id         :bigint(8)        not null, primary key
#  status_id  :bigint(8)        not null
#  domain     :string           default(""), not null
#  visibility :integer          default("public"), not null
#

class StatusDomainPermission < ApplicationRecord
  include Paginable
  include Cacheable

  validates :domain, presence: true, uniqueness: { scope: :status_id }
  validates :visibility, presence: true

  belongs_to :status, inverse_of: :domain_permissions
  enum visibility: [:public, :unlisted, :private, :direct, :limited], _suffix: :visibility

  default_scope { order(domain: :desc) }

  cache_associated :status

  class << self
    def create_by_domains(permissions_list)
      Array(permissions_list).map(&method(:normalize)).map do |permissions|
        where(**permissions).first_or_create
      end
    end

    def create_by_domains!(permissions_list)
      Array(permissions_list).map(&method(:normalize)).map do |permissions|
        where(**permissions).first_or_create!
      end
    end

    def create_or_update(domain_permissions)
      domain_permissions = normalize(domain_permissions)
      permissions = find_by(domain: domain_permissions[:domain])
      if permissions.present?
        permissions.update(**domain_permissions)
      else
        create(**domain_permissions)
      end
      permissions
    end

    def create_or_update!(domain_permissions)
      domain_permissions = normalize(domain_permissions)
      permissions = find_by(domain: domain_permissions[:domain])
      if permissions.present?
        permissions.update!(**domain_permissions)
      else
        create!(**domain_permissions)
      end
      permissions
    end

    private

    def normalize(hash)
      hash.symbolize_keys!
      hash[:domain] = hash[:domain].strip.downcase
      hash.compact
    end
  end
end
