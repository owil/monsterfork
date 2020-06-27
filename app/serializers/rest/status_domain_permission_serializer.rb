# frozen_string_literal: true

class REST::StatusDomainPermissionSerializer < ActiveModel::Serializer
  attributes :id, :domain, :visibility
  has_one :status

  def id
    object.id.to_s
  end
end
