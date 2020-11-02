# frozen_string_literal: true

module DomainControlHelper
  def domain_not_allowed?(uri_or_domain)
    return if uri_or_domain.blank?

    domain = begin
      if uri_or_domain.include?('://')
        Addressable::URI.parse(uri_or_domain).host
      else
        uri_or_domain
      end
    end

    domain != Rails.configuration.x.local_domain && (!DomainAllow.allowed?(domain) || DomainBlock.blocked?(domain))
  rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
    nil
  end

  def whitelist_mode?
    !(Rails.env.development? || Rails.env.test?)
  end
end
