# frozen_string_literal: true

class AccountDomainPermissionPolicy < ApplicationPolicy
  def update?
    owned?
  end

  def destroy?
    owned?
  end

  private

  def owned?
    record.account_id == current_account&.id
  end
end
