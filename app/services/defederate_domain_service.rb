# frozen_string_literal: true

class DefederateDomainService < BaseService
  def call(domains)
    return if domains.blank?

    Account.local.find_each do |account|
      DefederateAccountService.new.call(account, domains)
    end
  end
end
