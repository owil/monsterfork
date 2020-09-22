# frozen_string_literal: true

#                  .~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.                  #
###################              Cthulhu Code!              ###################
#                  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`                  #
# - Interprets and executes user input.  THIS CAN BE VERY DANGEROUS!          #
# - Has a high complexity level and needs tests.                              #
# - May destroy objects passed to it.                                         #
# - Incurs a high performance penalty.                                        #
#                                                                             #
###############################################################################

require_relative 'commands'

class CommandTag::Break < Mastodon::Error
  def initialize(msg = 'A handler stopped execution.')
    super
  end
end

class CommandTag::Processor
  include Redisable
  include ImgProxyHelper
  include CommandTag::Commands

  MENTIONS_OR_HASHTAGS_RE = /(?:(?:#{Account::MENTION_RE}|#{Tag::HASHTAG_RE})\s*)+/.freeze
  PARSEABLE_RE = /^\s*(?:#{MENTIONS_OR_HASHTAGS_RE})?#!|%%.+?%%/.freeze
  STATEMENT_RE = /^\s*#!\s*[^\n]+ (?:start|begin|do)$.*?\n\s*#!\s*(?:end|stop|done)\s*$|^\s*#!\s*.*?\s*$/im.freeze
  STATEMENT_PARSE_RE = /'([^']*)'|"([^"]*)"|(\S+)|\s+(?:start|begin|do)\s*$\n+(.*)\n\s*#!\s*(?:end|stop|done)\s*\z/im.freeze
  TEMPLATE_RE = /%%\s*(\S+.*?)\s*%%/.freeze
  ESCAPE_MAP = {
    '\n' => "\n",
    '\r' => "\r",
    '\t' => "\t",
    '\\\\' => '\\',
    '\%' => '%',
  }.freeze

  def initialize(account, status)
    @account      = account
    @status       = status
    @parent       = status.thread
    @conversation = status.conversation
    @text         = status.text
    @run_once     = Set[]
    @vars         = { 'statement_uuid' => [nil] }
    @statements   = {}

    return unless @account.present? && @account.local? && @status.present?
  end

  def process!
    reset_status_caches
    all_handlers!(:startup)

    unless @text.match?(PARSEABLE_RE)
      process_inline_images!
      @status.save!
      return
    end

    @text = parse_statements_from!(@text, @statements)

    execute_statements(:at_start)
    execute_statements(:with_return, true)
    @text = replace_templates(@text)
    execute_statements(:before_save)

    if status_text_blank?
      execute_statements(:when_blank)

      unless (@status.published? && !@status.edited.zero?) || @text.present?
        execute_statements(:before_destroy)
        @status.update(published: false)
        @status.destroy
        execute_statements(:after_destroy)
      end
    elsif @status.destroyed?
      execute_statements(:after_destroy)
    else
      @status.text = @text
      process_inline_images!
      if @status.save
        execute_statements(:after_save)
      else
        execute_statements(:after_save_fail)
      end
    end

    execute_statements(:at_end)
    all_handlers!(:shutdown)
  rescue CommandTag::Break
    nil
  rescue StandardError
    @status.update(published: false)
    @status.destroy
    raise
  ensure
    reset_status_caches
  end

  private

  def all_handlers!(affix)
    self.class.instance_methods.grep(/\Ahandle_\w+_#{affix}\z/).sort.each do |name|
      public_send(name)
    end
  end

  # Calls an arbitary public method (if it exists) on a given value and returns the result.
  def transform_using(name, value, args = [])
    respond_to?(name) ? public_send(name, value, args) : value
  end

  # Moves command tags placed after hashtags and mentions to their own line.
  def prepare_input(text)
    text.gsub(/\r\n|\n\r|\r/, "\n").gsub(/^\s*(#{MENTIONS_OR_HASHTAGS_RE})#!/, "\\1\n#!")
  end

  # Translates %%...%% templates.
  def replace_templates(text)
    text.gsub(TEMPLATE_RE) do
      template = unescape_literals(Regexp.last_match(1))
      next if template.blank?
      next template[1..-2] if template.match?(/\A'.*'\z/)

      template = template.match?(/\A".*"\z/) ? template[1..-2] : "\#{#{template}}"
      template.gsub(/#\{\s*(.*?)\s*\}/) do
        next if Regexp.last_match(1).blank?

        parts     = Regexp.last_match(1).scan(/'([^']*)'|"([^"]*)"|(\S+)/).flatten.compact
        name      = normalize(parts[0])
        separator = "\n"

        if parts.count > 2
          if %w(: by: with: using: sep: separator: delim: delimiter:).include?(parts[-2].downcase)
            separator = parts[-1]
            parts = parts[0..-3]
          elsif !parts[-1].match?(/\A[-+]?[0-9]+\z/)
            separator = parts[-1]
            parts.pop
          end
        end

        index       = to_integer(parts[1])
        str_start   = to_integer(parts[2])
        str_end     = to_integer(parts[3])

        str_start, str_end = [str_end, str_start] if str_start > str_end

        old_value = (['all', '[]'].include?(parts[1]) ? var(name).join(separator) : var(name)[index].to_s)
        name      = name.gsub(/[^\w_]+/, '_')
        new_value = transform_using("transform_#{name}_template_return", old_value, [index, str_start, str_end])
        next new_value if new_value != old_value

        new_value = transform_using("transform_#{name}_template_value", new_value, [index, str_start, str_end])
        (str_end - str_start).zero? ? new_value : new_value[str_start..str_end]
      end
    end.rstrip
  end

  # Parses statements from text and merges them into statement queues.
  # Mutates statement queues hash!
  def parse_statements_from!(text, statement_queues)
    @run_once.clear

    text = prepare_input(text)
    text.gsub!(STATEMENT_RE) do
      statement = unescape_literals(Regexp.last_match(0).strip[2..-1])
      next if statement.blank?

      statement_array = statement.scan(STATEMENT_PARSE_RE).flatten.compact.map { |arg| arg.gsub('\#!', '#!') }
      statement_array[0] = statement_array[0].strip.tr(':.\- ', '_').gsub(/__+/, '_').downcase
      next unless statement_array[0].match?(/\A[\w_]+\z/)

      statement_array[-1].rstrip! if statement_array.count > 1
      add_statement_handlers_for!(statement_array, statement_queues)
    end

    @run_once.clear
    text
  end

  # Yields all possible handler names for a command.
  def potential_handlers_for(name)
    ['_once', ''].each_with_index do |count_affix, index|
      %w(at_start with_return when_blank at_end).each do |when_affix|
        yield ["#{count_affix}_#{when_affix}", "handle_#{name}#{count_affix}_#{when_affix}", index.zero?]
      end

      %w(destroy save postprocess save_fail).each do |event_affix|
        %w(before after).each do |when_affix|
          yield ["#{count_affix}_#{when_affix}_#{event_affix}", "handle_#{name}#{count_affix}_#{when_affix}_#{event_affix}", index.zero?]
        end
      end
    end
  end

  # Expands a statement to a handler method call, arguments, and template UUID for each handler affix.
  # Mutates statement queues hash!
  def add_statement_handlers_for!(statement_array, statement_queues = {})
    statement_uuid = SecureRandom.uuid

    potential_handlers_for(statement_array[0]) do |when_affix, handler, once|
      if !(once && @run_once.include?(handler)) && respond_to?(handler)
        statement_queues[when_affix] ||= []
        statement_queues[when_affix] << [handler, statement_array[1..-1], statement_uuid]
        @run_once << handler if once
      end
    end

    # Template for statement return value.
    "%% statement:#{statement_uuid} all %%"
  end

  # Calls all handlers for a queue of statements in order.
  def execute_statements(event, with_return = false, statements: nil)
    statements = @statements if statements.blank?

    ["_#{event}", "_once_#{event}"].each do |when_affix|
      next if statements[when_affix].blank?

      statements[when_affix].each do |handler, arguments, uuid|
        @vars['statement_uuid'][0] = uuid
        if with_return
          @vars["statement:#{uuid}"] = [public_send(handler, arguments)]
        else
          public_send(handler, arguments)
        end
      end
    end
  end

  # Expire cached statuses after potentially updating them.
  def reset_status_caches(statuses = nil)
    statuses = [@status, @parent] if statuses.blank?
    statuses.each do |status|
      next unless @account.id == status&.account_id

      Rails.cache.delete_matched("statuses/#{status.id}-*")
      Rails.cache.delete("statuses/#{status.id}")
      Rails.cache.delete(status)
      Rails.cache.delete_matched("format:#{status.id}:*")
      redis.zremrangebyscore("spam_check:#{status.account.id}", status.id, status.id)
    end
  end

  def author_of_status?
    @account.id == @status.account_id
  end

  def author_of_parent?
    @account.id == @parent&.account_id
  end

  def status_text_blank?
    @text.blank? || @text.gsub(MENTIONS_OR_HASHTAGS_RE, '').strip.blank?
  end

  def destroy_status!
    return if @status.destroyed?

    @status.update(published: false)
    @status.destroy
  end

  def replace_status!(new_status)
    return if new_status.blank?

    destroy_status!
    @status = new_status
  end

  def normalize(text)
    text.to_s.strip.downcase
  end

  def to_integer(text)
    text&.strip.to_i
  end

  def unescape_literals(text)
    ESCAPE_MAP.each { |escaped, unescaped| text.gsub!(escaped, unescaped) }
    text
  end

  def html_encode(text)
    (@html_entities ||= HTMLEntities.new).encode(text)
  end

  def var(name)
    @vars[name].presence || []
  end

  def read_visibility_from(arg)
    return if arg.strip.blank?

    arg = case arg.strip
          when 'p', 'pu', 'all', 'world'
            'public'
          when 'u', 'ul'
            'unlisted'
          when 'f', 'follower', 'followers', 'packmates', 'follower-only', 'followers-only', 'packmates-only'
            'private'
          when 'd', 'dm', 'pm', 'directmessage'
            'direct'
          when 'default', 'reset'
            @account.user.setting_default_privacy
          when 'to', 'allow', 'allow-from', 'from'
            'cc'
          when 'm', 'l', 'mp', 'monsterpit', 'local'
            'community'
          else
            arg.strip
          end

    %w(public unlisted private limited direct cc community).include?(arg) ? arg : nil
  end

  def read_falsy_from(arg)
    %w(f n false no off disable).include?(arg)
  end

  def read_truthy_from(arg)
    %w(t y true yes on enable).include?(arg)
  end

  def read_boolean_from(arg)
    arg.present? && (read_truthy_from(arg) || !read_falsy_from(arg))
  end

  def normalize_domain(domain)
    return if domain&.strip.blank? || !domain.include?('.')

    domain.split('.').map(&:strip).reject(&:blank?).join('.').downcase
  end

  def federating_with_domain?(domain)
    return false if domain.blank?

    DomainAllow.where(domain: domain).exists? || Account.where(domain: domain, suspended_at: nil).exists?
  end
end
