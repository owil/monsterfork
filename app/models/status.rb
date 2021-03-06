# frozen_string_literal: true
# == Schema Information
#
# Table name: statuses
#
#  id                     :bigint(8)        not null, primary key
#  uri                    :string
#  text                   :text             default(""), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  in_reply_to_id         :bigint(8)
#  reblog_of_id           :bigint(8)
#  url                    :string
#  sensitive              :boolean          default(FALSE), not null
#  visibility             :integer          default("public"), not null
#  spoiler_text           :text             default(""), not null
#  reply                  :boolean          default(FALSE), not null
#  language               :string
#  conversation_id        :bigint(8)
#  local                  :boolean
#  account_id             :bigint(8)        not null
#  application_id         :bigint(8)
#  in_reply_to_account_id :bigint(8)
#  local_only             :boolean          default(FALSE), not null
#  poll_id                :bigint(8)
#  content_type           :string
#  deleted_at             :datetime
#  edited                 :integer          default(0), not null
#  nest_level             :integer          default(0), not null
#  published              :boolean          default(TRUE), not null
#  title                  :text
#  original_text          :text
#  footer                 :text
#  expires_at             :datetime
#  publish_at             :datetime
#  originally_local_only  :boolean          default(FALSE), not null
#  curated                :boolean          default(FALSE), not null
#

# rubocop:disable Metrics/ClassLength
class Status < ApplicationRecord
  before_destroy :unlink_from_conversations

  include Discard::Model
  include Paginable
  include Cacheable
  include StatusThreadingConcern
  include RateLimitable

  rate_limit by: :account, family: :statuses

  self.discard_column = :deleted_at

  # If `override_timestamps` is set at creation time, Snowflake ID creation
  # will be based on current time instead of `created_at`
  attr_accessor :override_timestamps

  update_index('statuses#status', :proper)

  enum visibility: [:public, :unlisted, :private, :direct, :limited], _suffix: :visibility

  belongs_to :application, class_name: 'Doorkeeper::Application', optional: true

  belongs_to :account, inverse_of: :statuses
  belongs_to :in_reply_to_account, foreign_key: 'in_reply_to_account_id', class_name: 'Account', optional: true
  belongs_to :conversation, optional: true
  belongs_to :preloadable_poll, class_name: 'Poll', foreign_key: 'poll_id', optional: true

  belongs_to :thread, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :replies, optional: true
  belongs_to :reblog, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblogs, optional: true

  has_many :favourites, inverse_of: :status, dependent: :destroy
  has_many :bookmarks, inverse_of: :status, dependent: :destroy
  has_many :reblogs, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblog, dependent: :destroy
  has_many :replies, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :thread
  has_many :mentions, dependent: :destroy, inverse_of: :status
  has_many :active_mentions, -> { active }, class_name: 'Mention', inverse_of: :status
  has_many :silent_mentions, -> { silent }, class_name: 'Mention', inverse_of: :status
  has_many :media_attachments, dependent: :nullify

  has_many :inlined_attachments, class_name: 'InlineMediaAttachment', inverse_of: :status, dependent: :destroy
  has_many :mutes, class_name: 'StatusMute', inverse_of: :status, dependent: :destroy
  belongs_to :conversation_mute, primary_key: 'conversation_id', foreign_key: 'conversation_id', inverse_of: :conversation, dependent: :destroy, optional: true
  has_many :domain_permissions, class_name: 'StatusDomainPermission', inverse_of: :status, dependent: :destroy
  has_many :queued_boosts, inverse_of: :status, dependent: :destroy

  has_and_belongs_to_many :tags
  has_and_belongs_to_many :preview_cards

  has_one :notification, as: :activity, dependent: :destroy
  has_one :status_stat, inverse_of: :status
  has_one :poll, inverse_of: :status, dependent: :destroy

  validates :uri, uniqueness: true, presence: true, unless: :local?
  validates :text, presence: true, unless: -> { with_media? || reblog? }
  validates_with StatusLengthValidator
  validates_with DisallowedHashtagsValidator
  validates :reblog, uniqueness: { scope: :account }, if: :reblog?
  validates :visibility, exclusion: { in: %w(direct limited) }, if: :reblog?
  validates :content_type, inclusion: { in: %w(text/plain text/markdown text/html) }, allow_nil: true

  accepts_nested_attributes_for :poll

  default_scope { recent.kept }

  scope :recent, -> { reorder(id: :desc) }
  scope :remote, -> { where(local: false).where.not(uri: nil) }
  scope :local,  -> { where(local: true).or(where(uri: nil)) }
  scope :with_accounts, ->(ids) { where(id: ids).includes(:account) }
  scope :without_replies, -> { where(reply: false) }
  scope :without_reblogs, -> { where('statuses.reblog_of_id IS NULL') }
  scope :with_public_visibility, -> { where(visibility: :public, published: true) }
  scope :distributable, -> { where(visibility: [:public, :unlisted], published: true) }
  scope :tagged_with, ->(tag_ids) { joins(:statuses_tags).where(statuses_tags: { tag_id: tag_ids }) }
  scope :in_chosen_languages, ->(account) { where(language: nil).or where(language: account.chosen_languages) }
  scope :excluding_silenced_accounts, -> { left_outer_joins(:account).where(accounts: { silenced_at: nil }) }
  scope :including_silenced_accounts, -> { left_outer_joins(:account).where.not(accounts: { silenced_at: nil }) }
  scope :not_excluded_by_account, ->(account) { where.not(account_id: account.excluded_from_timeline_account_ids) }
  scope :not_domain_blocked_by_account, ->(account) { account.excluded_from_timeline_domains.blank? ? left_outer_joins(:account) : left_outer_joins(:account).where('accounts.domain IS NULL OR accounts.domain NOT IN (?)', account.excluded_from_timeline_domains) }
  scope :tagged_with_all, ->(tag_ids) {
    Array(tag_ids).reduce(self) do |result, id|
      result.joins("INNER JOIN statuses_tags t#{id} ON t#{id}.status_id = statuses.id AND t#{id}.tag_id = #{id}")
    end
  }
  scope :tagged_with_none, ->(tag_ids) {
    Array(tag_ids).reduce(self) do |result, id|
      result.joins("LEFT OUTER JOIN statuses_tags t#{id} ON t#{id}.status_id = statuses.id AND t#{id}.tag_id = #{id}")
            .where("t#{id}.tag_id IS NULL")
    end
  }

  scope :not_local_only, -> { where(local_only: [false, nil]) }

  scope :including_unpublished, -> { unscope(where: :published) }
  scope :unpublished, -> { rewhere(published: false) }
  scope :published, -> { where(published: true) }
  scope :reblogs, -> { where('statuses.reblog_of_id IS NOT NULL') }
  scope :locally_reblogged, -> { where(id: Status.unscoped.local.reblogs.select(:reblog_of_id)) }
  scope :mentioning_account, ->(account) { joins(:mentions).where(mentions: { account: account }) }
  scope :replies, -> { where(reply: true) }
  scope :expired, -> { published.where('statuses.expires_at IS NOT NULL AND statuses.expires_at < ?', Time.now.utc) }
  scope :ready_to_publish, -> { unpublished.where('statuses.publish_at IS NOT NULL AND statuses.publish_at < ?', Time.now.utc) }
  scope :curated, -> { where(curated: true) }

  scope :not_hidden_by_account, ->(account) do
    left_outer_joins(:mutes, :conversation_mute).where('(status_mutes.account_id IS NULL OR status_mutes.account_id != ?) AND (conversation_mutes.account_id IS NULL OR conversation_mutes.account_id != ?)', account.id, account.id)
  end

  cache_associated :application,
                   :media_attachments,
                   :conversation,
                   :status_stat,
                   :tags,
                   :preview_cards,
                   :preloadable_poll,
                   account: :account_stat,
                   active_mentions: { account: :account_stat },
                   reblog: [
                     :application,
                     :tags,
                     :preview_cards,
                     :media_attachments,
                     :conversation,
                     :status_stat,
                     :preloadable_poll,
                     account: :account_stat,
                     active_mentions: { account: :account_stat },
                   ],
                   thread: { account: :account_stat }

  delegate :domain, to: :account, prefix: true
  delegate :max_visibility_for_domain, to: :account

  REAL_TIME_WINDOW = 6.hours
  SORTED_VISIBILITY = {
    direct: 0,
    limited: 1,
    private: 2,
    unlisted: 3,
    public: 4,
  }.with_indifferent_access.freeze
  TIMER_VALUES = [
    0, 1, 2, 3, 5, 10, 15, 30, 60, 120, 180, 360, 720, 1440, 2880, 4320, 7200,
    10_080, 20_160, 30_240, 60_480, 120_960, 181_440, 241_920, 362_880, 524_160
  ].freeze
  HISTORY_VALUES = [0, 1, 2, 3, 6, 12, 18, 24, 36, 52, 104, 156].freeze

  def searchable_by(preloaded = nil)
    ids = []

    ids << account_id if local?

    if preloaded.nil?
      ids += mentions.where(account: Account.local, silent: false).pluck(:account_id)
      ids += favourites.where(account: Account.local).pluck(:account_id)
      ids += reblogs.where(account: Account.local).pluck(:account_id)
      ids += bookmarks.where(account: Account.local).pluck(:account_id)
    else
      ids += preloaded.mentions[id] || []
      ids += preloaded.favourites[id] || []
      ids += preloaded.reblogs[id] || []
      ids += preloaded.bookmarks[id] || []
    end

    ids.uniq
  end

  def reply?
    !in_reply_to_id.nil? || attributes['reply']
  end

  def local?
    attributes['local'] || uri.nil?
  end

  def reblog?
    !reblog_of_id.nil?
  end

  def within_realtime_window?
    created_at >= REAL_TIME_WINDOW.ago
  end

  def verb
    if destroyed?
      :delete
    else
      reblog? ? :share : :post
    end
  end

  def object_type
    reply? ? :comment : :note
  end

  def proper
    reblog? ? reblog : self
  end

  def content
    proper.text
  end

  def target
    reblog
  end

  def preview_card
    preview_cards.first
  end

  def hidden?
    !(published? || distributable?)
  end

  def distributable?
    !account.private? && (public_visibility? || unlisted_visibility?)
  end

  alias sign? distributable?

  def with_media?
    media_attachments.any?
  end

  def non_sensitive_with_media?
    !sensitive? && with_media?
  end

  def reported?
    @reported ||= Report.where(target_account: account).unresolved.where('? = ANY(status_ids)', id).exists?
  end

  def emojis
    return @emojis if defined?(@emojis)

    fields  = [spoiler_text, text, footer || '']
    fields += preloadable_poll.options unless preloadable_poll.nil?

    @emojis = CustomEmoji.from_text(fields.join(' '), account.domain)
  end

  def mark_for_mass_destruction!
    @marked_for_mass_destruction = true
  end

  def marked_for_mass_destruction?
    @marked_for_mass_destruction
  end

  def replies_count
    status_stat&.replies_count || 0
  end

  def reblogs_count
    status_stat&.reblogs_count || 0
  end

  def favourites_count
    status_stat&.favourites_count || 0
  end

  def increment_count!(key)
    update_status_stat!(key => public_send(key) + 1)
  end

  def decrement_count!(key)
    update_status_stat!(key => [public_send(key) - 1, 0].max)
  end

  def curate!
    return false unless !curated? && published? && public_visibility?

    update_column(:curated, true)
    true
  end

  def uncurate!
    return false unless curated?

    update_column(:curated, false)
    true
  end

  def notify=(value)
    Redis.current.set("status:#{id}:notify", value ? 1 : 0, ex: 1.hour)
    @notify = value
  end

  def notify
    return @notify if defined?(@notify)

    value = Redis.current.get("status:#{id}:notify")
    @notify = value.nil? ? true : value.to_i == 1
  end

  alias notify? notify

  def less_private_than?(other_visibility)
    return false if other_visibility.blank?

    SORTED_VISIBILITY[visibility] > SORTED_VISIBILITY[other_visibility]
  end

  def more_private_than?(other_visibility)
    return false if other_visibility.blank?

    SORTED_VISIBILITY[visibility] < SORTED_VISIBILITY[other_visibility]
  end

  def visibility_for_domain(domain)
    return visibility.to_s if domain.blank?
    return 'private' if account.private?

    v = domain_permissions.find_by(domain: [domain, '*'])&.visibility || visibility.to_s

    case max_visibility_for_domain(domain)
    when 'public'
      v
    when 'unlisted'
      v == 'public' ? 'unlisted' : v
    when 'private'
      %w(public unlisted).include?(v) ? 'private' : v
    when 'direct'
      'direct'
    else
      v != 'direct' ? 'limited' : 'direct'
    end
  end

  def public_domain_permissions?
    return @public_permissions if defined?(@public_permissions)
    return @public_permissions = false unless account.local?

    @public_permissions = domain_permissions.where(visibility: [:public, :unlisted]).exists?
  end

  def private_domain_permissions?
    return @private_permissions if defined?(@private_permissions)
    return @private_permissions = false unless account.local?

    @private_permissions = domain_permissions.where(visibility: [:private, :direct, :limited]).exists?
  end

  def should_limit_visibility?
    less_private_than?(thread&.visibility)
  end

  after_create_commit  :increment_counter_caches
  after_destroy_commit :decrement_counter_caches

  after_create_commit :store_uri, if: :local?
  after_create_commit :store_url, if: :local?
  after_create_commit :update_statistics, if: :local?

  around_create Mastodon::Snowflake::Callbacks

  before_create :set_locality
  before_create :set_nest_level

  before_validation :prepare_contents, if: :local?
  before_validation :set_reblog
  before_validation :set_conversation_perms
  before_validation :set_local

  after_create :set_poll_id

  after_save :set_domain_permissions, if: :local?
  after_save :set_conversation_root

  class << self
    def selectable_visibilities
      visibilities.keys - %w(direct limited)
    end

    def in_chosen_languages(account)
      where(language: nil).or where(language: account.chosen_languages)
    end

    def as_direct_timeline(account, limit = 20, max_id = nil, since_id = nil, cache_ids = false)
      # direct timeline is mix of direct message from_me and to_me.
      # 2 queries are executed with pagination.
      # constant expression using arel_table is required for partial index

      # _from_me part does not require any timeline filters
      query_from_me = where(account_id: account.id)
                      .where(Status.arel_table[:visibility].eq(3))
                      .limit(limit)
                      .order('statuses.id DESC')

      # _to_me part requires mute and block filter.
      # FIXME: may we check mutes.hide_notifications?
      query_to_me = Status
                    .joins(:mentions)
                    .merge(Mention.where(account_id: account.id))
                    .where(Status.arel_table[:visibility].eq(3))
                    .limit(limit)
                    .order('mentions.status_id DESC')
                    .not_excluded_by_account(account)

      if max_id.present?
        query_from_me = query_from_me.where('statuses.id < ?', max_id)
        query_to_me = query_to_me.where('mentions.status_id < ?', max_id)
      end

      if since_id.present?
        query_from_me = query_from_me.where('statuses.id > ?', since_id)
        query_to_me = query_to_me.where('mentions.status_id > ?', since_id)
      end

      if cache_ids
        # returns array of cache_ids object that have id and updated_at
        (query_from_me.cache_ids.to_a + query_to_me.cache_ids.to_a).uniq(&:id).sort_by(&:id).reverse.take(limit)
      else
        # returns ActiveRecord.Relation
        items = (query_from_me.select(:id).to_a + query_to_me.select(:id).to_a).uniq(&:id).sort_by(&:id).reverse.take(limit)
        Status.where(id: items.map(&:id))
      end
    end

    def favourites_map(status_ids, account_id)
      Favourite.select('status_id').where(status_id: status_ids).where(account_id: account_id).each_with_object({}) { |f, h| h[f.status_id] = true }
    end

    def bookmarks_map(status_ids, account_id)
      Bookmark.select('status_id').where(status_id: status_ids).where(account_id: account_id).map { |f| [f.status_id, true] }.to_h
    end

    def reblogs_map(status_ids, account_id)
      unscoped.select('reblog_of_id').where(reblog_of_id: status_ids).where(account_id: account_id).each_with_object({}) { |s, h| h[s.reblog_of_id] = true }
    end

    def mutes_map(conversation_ids, account_id)
      ConversationMute.select('conversation_id').where(conversation_id: conversation_ids).where(account_id: account_id).each_with_object({}) { |m, h| h[m.conversation_id] = true }
    end

    def hidden_statuses_map(status_ids, account_id)
      StatusMute.select('status_id').where(status_id: status_ids).where(account_id: account_id).each_with_object({}) { |m, h| h[m.status_id] = true }
    end

    def pins_map(status_ids, account_id)
      StatusPin.select('status_id').where(status_id: status_ids).where(account_id: account_id).each_with_object({}) { |p, h| h[p.status_id] = true }
    end

    def reload_stale_associations!(cached_items)
      account_ids = []

      cached_items.each do |item|
        account_ids << item.account_id
        account_ids << item.reblog.account_id if item.reblog?
      end

      account_ids.uniq!

      return if account_ids.empty?

      accounts = Account.where(id: account_ids).includes(:account_stat).each_with_object({}) { |a, h| h[a.id] = a }

      cached_items.each do |item|
        item.account = accounts[item.account_id]
        item.reblog.account = accounts[item.reblog.account_id] if item.reblog?
      end
    end

    def permitted_for(target_account, account, **options)
      visibility = [:public, :unlisted]

      if account.present?
        return none if target_account.blocking?(account) || (account.domain.present? && target_account.domain_blocking?(account.domain))
        return apply_category_filters(all, target_account, account, **options) if account.id == target_account.id

        visibility.push(:private) if account.following?(target_account)
      end

      visibility = :public if options[:public] || (account.blank? && !target_account.show_unlisted?)

      scope = where(visibility: visibility)
      apply_category_filters(scope, target_account, account, **options)
    end

    def mentions_between(account, target_account)
      return none if account.blank? || target_account.blank?

      account.statuses.mentioning_account(target_account).or(target_account.statuses.mentioning_account(account))
    end

    def from_text(text)
      return [] if text.blank?

      text.scan(FetchLinkCardService::URL_PATTERN).map(&:first).uniq.map do |url|
        status = begin
          if TagManager.instance.local_url?(url)
            ActivityPub::TagManager.instance.uri_to_resource(url, Status)
          else
            EntityCache.instance.status(url)
          end
        end
        status&.distributable? ? status : nil
      end.compact
    end

    private

    # TODO: Cast cleanup spell.
    # rubocop:disable Metrics/PerceivedComplexity
    def apply_category_filters(query, target_account, account, **options)
      options[:without_account_filters] ||= target_account.id == account&.id
      query = apply_account_filters(query, account, **options)
      return query if options[:without_category_filters]

      query = query.published unless options[:include_unpublished]

      if options[:only_reblogs]
        query = query.joins(:reblog)
        if account.present? && account.excluded_from_timeline_account_ids.present?
          query = query.where.not(
            reblogs_statuses: { account_id: account.excluded_from_timeline_account_ids }
          )
        end
      elsif target_account.id == account&.id
        query = query.without_replies unless options[:include_replies] || options[:only_replies]
        query = query.without_reblogs unless options[:include_reblogs] || options[:only_reblogs]
        query = query.reblogs if options[:only_reblogs]
        query = query.replies if options[:only_replies]
      else
        if options[:include_reblogs] && account.present? && account.excluded_from_timeline_account_ids.present?
          query = query.left_outer_joins(:reblog).where(
            '(statuses.reblog_of_id IS NULL OR reblogs_statuses.account_id NOT IN (?))',
            account.excluded_from_timeline_account_ids
          )
        elsif !options[:include_reblogs]
          query = query.without_reblogs
        end

        if options[:include_replies]
          query = query.replies if options[:only_replies]
        else
          query = query.without_replies
        end
      end

      if target_account.id != account&.id && target_account&.user&.max_history_public.present?
        history_limit = account&.following?(target_account) ? target_account.user.max_history_private : target_account.user.max_history_public
        query = query.where('statuses.updated_at >= ?', history_limit.weeks.ago) if history_limit.positive?
      end

      return query if options[:tag].blank?

      (tag = Tag.find_normalized(options[:tag])) ? query.merge(Status.tagged_with(tag.id)) : none
    end
    # rubocop:enable Metrics/PerceivedComplexity

    def apply_account_filters(query, account, **options)
      return query.not_local_only if account.blank?
      return (!options[:exclude_local_only] && account.local? ? query : query.not_local_only) if options[:without_account_filters]

      query = query.not_local_only unless !options[:exclude_local_only] && account.local?
      query = query.not_hidden_by_account(account)
      query = query.in_chosen_languages(account) if account.chosen_languages.present?
      query
    end
  end

  def marked_local_only?
    # match both with and without U+FE0F (the emoji variation selector)
    /#{local_only_emoji}\ufe0f?\z/.match?(content)
  end

  def local_only_emoji
    '👁'
  end

  def status_stat
    super || build_status_stat
  end

  private

  def update_status_stat!(attrs)
    return if marked_for_destruction? || destroyed?

    status_stat.update(attrs)
  end

  def store_uri
    update_column(:uri, ActivityPub::TagManager.instance.uri_for(self)) if uri.nil?
  end

  def store_url
    update_column(:url, ActivityPub::TagManager.instance.url_for(self)) if url.nil?
  end

  def prepare_contents
    text&.strip!
    spoiler_text&.strip!
    title&.strip!
    language&.gsub!('en-MP', 'en')
  end

  def set_reblog
    self.reblog = reblog.reblog if reblog? && reblog.reblog?
  end

  def set_poll_id
    update_column(:poll_id, poll.id) unless poll.nil?
  end

  def set_locality
    if account.domain.nil? && !attribute_changed?(:local_only)
      self.local_only = true if marked_local_only?
    end
    self.local_only = true if thread&.local_only? && local_only.nil?
    self.local_only = reblog.local_only if reblog?

    self.originally_local_only = local_only if attribute_changed?(:local_only) && !attribute_changed?(:originally_local_only)
  end

  def set_conversation_perms
    self.thread = thread.reblog if thread&.reblog?
    self.reply = !(in_reply_to_id.nil? && thread.nil?) unless reply
    self.visibility = reblog.visibility if reblog? && visibility.nil?
    self.visibility = (account.locked? ? :private : :public) if visibility.nil?
    self.visibility = thread.visibility if should_limit_visibility?
    self.sensitive  = account.sensitized? if sensitive.nil?

    if reply? && !thread.nil?
      self.in_reply_to_account_id = carried_over_reply_to_account_id
      self.conversation_id        = thread.conversation_id if conversation_id.nil?
      self.visibility             = :limited if in_reply_to_account_id != account_id && (visibility.to_s == 'private' || account.private?)
    end
  end

  def set_conversation_root
    conversation.update!(root: uri) if !reply && conversation.present? && conversation.root.blank?
  end

  def carried_over_reply_to_account_id
    if thread.account_id == account_id && thread.reply?
      thread.in_reply_to_account_id
    else
      thread.account_id
    end
  end

  def set_local
    self.local = account.local?
  end

  def set_nest_level
    return if attribute_changed?(:nest_level)

    self.nest_level = if reply?
                        [thread&.account_id == account_id ? thread&.nest_level.to_i : thread&.nest_level.to_i + 1, 127].min
                      else
                        0
                      end
  end

  def set_domain_permissions
    return unless saved_change_to_visibility?

    domain_permissions.transaction do
      existing_domains = domain_permissions.select(:domain)
      permissions = account.domain_permissions.where.not(domain: existing_domains)
      permissions.find_each do |permission|
        domain_permissions.create!(domain: permission.domain, visibility: permission.visibility) if less_private_than?(permission.visibility)
      end
    end
  end

  def update_statistics
    return unless distributable?

    ActivityTracker.increment('activity:statuses:local')
  end

  def increment_counter_caches
    return if direct_visibility?

    account&.increment_count!(:statuses_count)
    reblog&.increment_count!(:reblogs_count) if reblog?
    thread&.increment_count!(:replies_count) if in_reply_to_id.present? && distributable?
  end

  def decrement_counter_caches
    return if direct_visibility? || marked_for_mass_destruction?

    account&.decrement_count!(:statuses_count)
    reblog&.decrement_count!(:reblogs_count) if reblog?
    thread&.decrement_count!(:replies_count) if in_reply_to_id.present? && distributable?
  end

  def unlink_from_conversations
    return unless direct_visibility?

    mentioned_accounts = mentions.includes(:account).map(&:account)
    inbox_owners       = mentioned_accounts.select(&:local?) + (account.local? ? [account] : [])

    inbox_owners.each do |inbox_owner|
      AccountConversation.remove_status(inbox_owner, self)
    end
  end
end
# rubocop:enable Metrics/ClassLength
