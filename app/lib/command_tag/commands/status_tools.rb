# frozen_string_literal: true
module CommandTag::Commands::StatusTools
  def handle_boost_once_at_start(args)
    return unless @parent.present? && StatusPolicy.new(@account, @parent).reblog?

    status = ReblogService.new.call(
      @account, @parent,
      visibility: @status.visibility,
      spoiler_text: args.join(' ').presence || @status.spoiler_text
    )
  end

  alias handle_reblog_at_start handle_boost_once_at_start
  alias handle_rb_at_start handle_boost_once_at_start
  alias handle_rt_at_start handle_boost_once_at_start

  def handle_article_before_save(args)
    return unless author_of_status? && args.present?

    case args.shift.downcase
    when 'title', 'name', 't'
      status.title = args.join(' ')
    when 'summary', 'abstract', 'cw', 'cn', 's', 'a'
      @status.title = @status.spoiler_text if @status.title.blank?
      @status.spoiler_text = args.join(' ')
    end
  end

  def handle_title_before_save(args)
    args.unshift('title')
    handle_article_before_save(args)
  end

  def handle_summary_before_save(args)
    args.unshift('summary')
    handle_article_before_save(args)
  end

  alias handle_abstract_before_save handle_summary_before_save

  def handle_visibility_before_save(args)
    return unless author_of_status? && args[0].present?

    args[0] = read_visibility_from(args[0])
    return if args[0].blank?

    if args[1].blank?
      @status.visibility = args[0].to_sym
    elsif args[0] == @status.visibility.to_s
      domains = args[1..-1].map { |domain| normalize_domain(domain) unless domain == '*' }.uniq.compact
      @status.domain_permissions.where(domain: domains).destroy_all if domains.present?
    elsif args[0] == 'cc'
      expect_list = false
      args[1..-1].uniq.each do |target|
        if expect_list
          expect_list = false
          address_to_list(target)
        elsif %w(list list:).include?(target.downcase)
          expect_list = true
        else
          mention(resolve_mention(target))
        end
      end
    elsif args[0] == 'community'
      @status.visibility = :public
      @status.domain_permissions.create_or_update(domain: '*', visibility: :unlisted)
    else
      args[1..-1].flat_map(&:split).uniq.each do |domain|
        domain = normalize_domain(domain) unless domain == '*'
        @status.domain_permissions.create_or_update(domain: domain, visibility: args[0]) if domain.present?
      end
    end
  end

  alias handle_v_before_save                      handle_visibility_before_save
  alias handle_p_before_save                      handle_visibility_before_save
  alias handle_privacy_before_save                handle_visibility_before_save

  def handle_local_only_before_save(args)
    @status.local_only = args.present? ? read_boolean_from(args[0]) : true
    @status.originally_local_only = @status.local_only?
  end

  def handle_federate_before_save(args)
    @status.local_only = args.present? ? !read_boolean_from(args[0]) : false
    @status.originally_local_only = @status.local_only?
  end

  def handle_notify_before_save(args)
    return if args[0].blank?

    @status.notify = read_boolean_from(args[0])
  end

  alias handle_notice_before_save handle_notify_before_save

  def handle_tags_before_save(args)
    return if args.blank?

    cmd = args.shift.downcase
    args.select! { |tag| tag =~ /\A(#{Tag::HASHTAG_NAME_RE})\z/i }

    case cmd
    when 'add', 'a', '+'
      ProcessHashtagsService.new.call(@status, args)
    when 'del', 'remove', 'rm', 'r', 'd', '-'
      RemoveHashtagsService.new.call(@status, args)
    end
  end

  def handle_tag_before_save(args)
    args.unshift('add')
    handle_tags_before_save(args)
  end

  def handle_untag_before_save(args)
    args.unshift('del')
    handle_tags_before_save(args)
  end

  def handle_delete_before_save(args)
    unless args
      RemovalWorker.perform_async(@parent.id, immediate: true) if author_of_parent? && status_text_blank?
      return
    end

    args.flat_map(&:split).uniq.each do |id|
      if id.match?(/\A\d+\z/)
        object = @account.statuses.find_by(id: id)
      elsif id.start_with?('https://')
        begin
          object = ActivityPub::TagManager.instance.uri_to_resource(id, Status)
          if object.blank? && ActivityPub::TagManager.instance.local_uri?(id)
            id = Addressable::URI.parse(id)&.normalized_path&.sub(/\A.*\/([^\/]*)\/*/, '\1')
            next unless id.present? && id.match?(/\A\d+\z/)

            object = find_status_or_create_stub(id)
          end
        rescue Addressable::URI::InvalidURIError
          next
        end
      end

      next if object.blank? || object.account_id != @account.id

      RemovalWorker.perform_async(object.id, immediate: true, unpublished: true)
    end
  end

  alias handle_destroy_before_save handle_delete_before_save
  alias handle_redraft_before_save handle_delete_before_save

  def handle_expires_before_save(args)
    return if args.blank?

    @status.expires_at = Time.now.utc + to_datetime(args)
  end

  alias handle_expires_in_before_save handle_expires_before_save
  alias handle_delete_in_before_save handle_expires_before_save
  alias handle_unpublish_in_before_save handle_expires_before_save

  def handle_publish_before_save(args)
    return if args.blank?

    @status.published = false
    @status.publish_at = Time.now.utc + to_datetime(args)
  end

  alias handle_publish_in_before_save handle_publish_before_save

  private

  def resolve_mention(mention_text)
    return unless (match = mention_text.match(Account::MENTION_RE))

    username, domain  = match[1].split('@')
    domain            = begin
                          if TagManager.instance.local_domain?(domain)
                            nil
                          else
                            TagManager.instance.normalize_domain(domain)
                          end
                        end

    Account.find_remote(username, domain)
  end

  def mention(target_account)
    return if target_account.blank? || target_account.mentions.where(status: @status).exists?

    target_account.mentions.create(status: @status, silent: true)
  end

  def address_to_list(list_name)
    return if list_name.blank?

    list_accounts = ListAccount.joins(:list).where(lists: { account: @account }).where('LOWER(lists.title) = ?', list_name.mb_chars.downcase).includes(:account).map(&:account)
    list_accounts.each { |target_account| mention(target_account) }
  end

  def find_status_or_create_stub(id)
    status_params = {
      id: id,
      account: @account,
      text: '(Deleted)',
      local: true,
      visibility: :public,
      local_only: false,
      published: false,
    }
    Status.where(id: id).first_or_create(status_params)
  end

  def to_datetime(args)
    total = 0.seconds
    args.reject { |arg| arg.blank? || %w(in at , and).include?(arg) }.in_groups_of(2) { |i, unit| total += to_duration(i.to_i, unit) }
    total
  end

  def to_duration(amount, unit)
    case unit
    when nil, 's', 'sec', 'secs', 'second', 'seconds'
      amount.seconds
    when 'm', 'min', 'mins', 'minute', 'minutes'
      amount.minutes
    when 'h', 'hr', 'hrs', 'hour', 'hours'
      amount.hours
    when 'd', 'day', 'days'
      amount.days
    when 'w', 'wk', 'wks', 'week', 'weeks'
      amount.weeks
    when 'mo', 'mos', 'mn', 'mns', 'month', 'months'
      amount.months
    when 'y', 'yr', 'yrs', 'year', 'years'
      amount.years
    end
  end
end
