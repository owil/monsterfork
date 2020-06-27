# frozen_string_literal: true

class StatusPolicy < ApplicationPolicy
  def initialize(current_account, record, preloaded_relations = {})
    super(current_account, record)

    @preloaded_relations = preloaded_relations
  end

  def index?
    staff?
  end

  def show?
    return false if local_only? && !current_account&.local?
    return false unless published? || owned?

    if requires_mention?
      owned? || mention_exists?
    elsif private?
      owned? || following_owners? || mention_exists?
    else
      current_account.nil? || !blocked_by_owners?
    end
  end

  def reblog?
    published? && !requires_mention? && (!private? || owned?) && show? && !blocking_author?
  end

  def favourite?
    show? && !blocking_author?
  end

  def destroy?
    staff? || owned?
  end

  alias unreblog? destroy?

  def update?
    staff?
  end

  private

  def requires_mention?
    %w(direct limited).include?(visibility_for_remote_domain)
  end

  def owned?
    author.id == current_account&.id
  end

  def private?
    visibility_for_remote_domain == 'private'
  end

  def mention_exists?
    return false if current_account.nil?

    if record.mentions.loaded?
      record.mentions.any? { |mention| mention.account_id == current_account.id }
    else
      record.mentions.where(account: current_account).exists?
    end
  end

  def author_blocking_domain?
    return false if current_account.nil? || current_account.domain.nil?

    author.domain_blocking?(current_account.domain)
  end

  def conversation_author_blocking_domain?
    return false if current_account.nil? || current_account.domain.nil? || conversation_owner.nil?

    conversation_owner.domain_blocking?(current_account.domain)
  end

  def blocking_author?
    return false if current_account.nil?

    @preloaded_relations[:blocking] ? @preloaded_relations[:blocking][author.id] : current_account.blocking?(author)
  end

  def author_blocking?
    return author.require_auth? if current_account.nil?

    @preloaded_relations[:blocked_by] ? @preloaded_relations[:blocked_by][author.id] : author.blocking?(current_account)
  end

  def conversation_author_blocking?
    return false if conversation_owner.nil?

    @preloaded_relations[:blocked_by] ? @preloaded_relations[:blocked_by][conversation_owner.id] : conversation_owner.blocking?(current_account)
  end

  def blocked_by_owners?
    return author_blocking? || author_blocking_domain? if conversation_owner&.id == author.id
    return true if conversation_author_blocking? || author_blocking?

    conversation_author_blocking_domain? || author_blocking_domain?
  end

  def following_author?
    return false if current_account.nil?

    @preloaded_relations[:following] ? @preloaded_relations[:following][author.id] : current_account.following?(author)
  end

  def following_conversation_owner?
    return false if current_account.nil? || conversation_owner.nil?

    @preloaded_relations[:following] ? @preloaded_relations[:following][conversation_owner.id] : current_account.following?(conversation_owner)
  end

  def following_owners?
    return following_author? if conversation_owner&.id == author.id

    following_conversation_owner? && following_author?
  end

  def author
    @author ||= record.account
  end

  def conversation_owner
    @conversation_owner ||= record.conversation&.account
  end

  def local_only?
    record.local_only?
  end

  def published?
    record.published?
  end

  def reply?
    record.reply? && record.in_reply_to_account_id != author.id
  end

  def visibility_for_remote_domain
    @visibility_for_domain ||= record.visibility_for_domain(current_account&.domain)
  end
end
