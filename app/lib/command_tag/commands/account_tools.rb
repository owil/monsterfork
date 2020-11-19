# frozen_string_literal: true
module CommandTag::Commands::AccountTools
  def handle_account_at_start(args)
    return if args[0].blank?

    case args[0].downcase
    when 'set'
      handle_account_set(args[1..-1])
    end
  end

  alias handle_acct_at_start handle_account_at_start

  private

  def handle_account_set(args)
    return if args[0].blank?

    case args[0].downcase
    when 'v', 'p', 'visibility', 'privacy', 'default-visibility', 'default-privacy'
      args[1] = read_visibility_from(args[1])
      return if args[1].blank?

      if args[2].blank?
        @account.user.settings.default_privacy = args[1]
      elsif args[1] == 'public'
        domains = args[2..-1].map { |domain| normalize_domain(domain) unless domain == '*' }.uniq.compact
        @account.domain_permissions.where(domain: domains, sticky: false).destroy_all if domains.present?
      elsif args[1] != 'cc'
        args[2..-1].flat_map(&:split).uniq.each do |domain|
          domain = normalize_domain(domain) unless domain == '*'
          @account.domain_permissions.create_or_update(domain: domain, visibility: args[1]) if domain.present?
        end
      end
    end
  end
end
