# frozen_string_literal: true

class REST::AccountDomainPermissionSerializer < ActiveModel::Serializer
  attributes :id, :domain, :visibility

  def id
    object.id.to_s
  end
end
