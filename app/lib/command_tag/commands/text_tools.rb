# frozen_string_literal: true

module CommandTag::Commands::TextTools
  def handle_code_at_start(args)
    return if args.count < 2

    name = normalize(args[0])
    value = args.last.presence || ''
    @vars[name] = case @status.content_type
                  when 'text/markdown'
                    ["```\n#{value}\n```"]
                  when 'text/html'
                    ["<pre><code>#{html_encode(value).gsub("\n", '<br/>')}</code></pre>"]
                  else
                    ["----------\n#{value}\n----------"]
                  end
  end

  def handle_code_with_return(args)
    return if args.count > 1

    value = args.last.presence || ''
    case @status.content_type
    when 'text/markdown'
      ["```\n#{value}\n```"]
    when 'text/html'
      ["<pre><code>#{html_encode(value).gsub("\n", '<br/>')}</code></pre>"]
    else
      ["----------\n#{value}\n----------"]
    end
  end

  def handle_prepend_before_save(args)
    args.each { |arg| @text = "#{arg}\n#{text}" }
  end

  def handle_append_before_save(args)
    args.each { |arg| @text << "\n#{arg}" }
  end

  def handle_replace_before_save(args)
    @text.gsub!(args[0], args[1] || '')
  end

  alias handle_sub_before_save handle_replace_before_save

  def handle_regex_replace_before_save(args)
    flags     = normalize(args[2])
    re_opts   = (flags.include?('i') ? Regexp::IGNORECASE : 0)
    re_opts  |= (flags.include?('x') ? Regexp::EXTENDED : 0)
    re_opts  |= (flags.include?('m') ? Regexp::MULTILINE : 0)

    @text.gsub!(Regexp.new(args[0], re_opts), args[1] || '')
  end

  alias handle_resub_before_save handle_replace_before_save
  alias handle_regex_sub_before_save handle_replace_before_save

  def handle_keysmash_with_return(args)
    keyboard = [
      'asdf', 'jkl;',
      'gh', "'",
      'we', 'io',
      'r', 'u',
      'cv', 'nm',
      't', 'x', ',',
      'q', 'z',
      'y', 'b',
      'p', '.',
      '[', ']'
    ]

    min_size = [[5, args[1].to_i].max, 100].min
    max_size = [args[0].to_i, 100].min
    max_size = 33 unless max_size.positive?

    min_size, max_size = [max_size, min_size] if min_size > max_size

    chunk = rand(min_size..max_size).times.map do
      keyboard[(keyboard.size * (rand**3)).floor].split('').sample
    end

    chunk.join
  end

  def transform_keysmash_template_return(_, args)
    handle_keysmash_with_return([args[0], args[2]])
  end
end
