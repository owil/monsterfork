# frozen_string_literal: true

class CustomEmojiPolicy < ApplicationPolicy
  def index?
    user_signed_in?
  end

  def create?
    user_signed_in?
  end

  def update?
    user_signed_in? && owned?
  end

  def copy?
    staff? || (user_signed_in? && new_or_owned?)
  end

  def enable?
    user_signed_in? && owned?
  end

  def disable?
    user_signed_in? && owned?
  end

  def destroy?
    user_signed_in? && owned?
  end

  def claim?
    staff? || claimable?
  end

  def unclaim?
    user_signed_in? && owned?
  end

  private

  def owned?
    staff? || (current_account.present? && record.account_id == current_account.id)
  end

  def new_or_owned?
    !CustomEmoji.where(domain: nil, shortcode: record.shortcode).where('account_id IS NULL OR account_id != ?', current_account.id).exists?
  end

  def claimable?
    record.local? ? record.account_id.blank? || record.account_id == current_account.id : new_or_owned?
  end
end
