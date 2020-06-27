# frozen_string_literal: true

class ResolveMentionsService < BaseService
  # Scan text for mentions and create local mention pointers
  # @param [Status] status Status to attach to mention pointers
  # @option [String] :text Text containing mentions to resolve (default: use status text)
  # @option [Enumerable] :mentions Additional mentions to include
  # @return [Array] Array containing text with mentions resolved (String) and mention pointers (Set)
  def call(status, text: nil, mentions: [])
    mentions                  = Mention.includes(:account).where(id: mentions.pluck(:id), accounts: { suspended_at: nil }).or(status.mentions.includes(:account))
    implicit_mention_acct_ids = mentions.active.pluck(:account_id).to_set
    text                      = status.text if text.nil?
    mentions                  = mentions.to_set

    text.gsub(Account::MENTION_RE) do |match|
      username, domain = Regexp.last_match(1).split('@')

      domain = begin
        if TagManager.instance.local_domain?(domain)
          nil
        else
          TagManager.instance.normalize_domain(domain)
        end
      end

      mentioned_account = Account.find_remote(username, domain)

      if mention_undeliverable?(mentioned_account)
        begin
          mentioned_account = resolve_account_service.call(Regexp.last_match(1))
        rescue Goldfinger::Error, HTTP::Error, OpenSSL::SSL::SSLError, Mastodon::UnexpectedResponseError
          mentioned_account = nil
        end
      end

      next match if mention_undeliverable?(mentioned_account) || mentioned_account&.suspended?

      mention = mentioned_account.mentions.where(status: status).first_or_create(status: status, silent: false)
      mention.update(silent: false) if mention.silent?

      mentions << mention
      implicit_mention_acct_ids.delete(mentioned_account.id)

      "@#{mentioned_account.acct}"
    end

    Mention.where(id: implicit_mention_acct_ids).update_all(silent: true)

    [text, mentions]
  end

  private

  def mention_undeliverable?(mentioned_account)
    mentioned_account.nil? || (!mentioned_account.local? && mentioned_account.ostatus?)
  end

  def resolve_account_service
    ResolveAccountService.new
  end
end
