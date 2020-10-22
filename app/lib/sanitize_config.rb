# frozen_string_literal: true

class Sanitize
  module Config
    HTTP_PROTOCOLS = %w(
      http
      https
    ).freeze

    LINK_PROTOCOLS = %w(
      http
      https
      dat
      dweb
      ipfs
      ipns
      ssb
      gopher
      xmpp
      magnet
      gemini
    ).freeze

    CLASS_WHITELIST_TRANSFORMER = lambda do |env|
      node = env[:node]
      class_list = node['class']&.split(/[\t\n\f\r ]/)

      return unless class_list

      class_list.keep_if do |e|
        next true if e =~ /^(h|p|u|dt|e)-/ # microformats classes
        next true if e =~ /^(mention|hashtag)$/ # semantic classes
        next true if e =~ /^(ellipsis|invisible)$/ # link formatting classes
        next true if %w(center centered abstract).include?(e)
      end

      node['class'] = class_list.join(' ')
    end

    DATA_NAME_ALLOWLIST_TRANSFORMER = lambda do |env|
      node = env[:node]
      name_list = node['data-name']&.split(/[\t\n\f\r ]/)

      return unless name_list

      name_list.keep_if do |name|
        next true if %w(summary abstract permalink footer).include?(name)
      end

      node['data-name'] = name_list.join(' ')
    end

    LINK_REL_TRANSFORMER = lambda do |env|
      return unless env[:node_name] == 'a' and env[:node]['href']

      node = env[:node]

      rel = (node['rel'] || '').split(' ') & ['tag']
      unless env[:config][:outgoing] && TagManager.instance.local_url?(node['href'])
        rel += ['nofollow', 'noopener', 'noreferrer']
      end
      node['rel'] = rel.join(' ')
    end

    UNSUPPORTED_HREF_TRANSFORMER = lambda do |env|
      return unless env[:node_name] == 'a'

      current_node = env[:node]

      scheme = begin
        if current_node['href'] =~ Sanitize::REGEX_PROTOCOL
          Regexp.last_match(1).downcase
        else
          :relative
        end
      end

      current_node.replace(current_node.text) unless LINK_PROTOCOLS.include?(scheme)
    end

    MASTODON_STRICT ||= freeze_config(
      elements: %w(p br span a abbr del pre blockquote code b strong u sub sup i em h1 h2 h3 h4 h5 ul ol li img h6 s center details summary),

      attributes: {
        'a'          => %w(href rel class title),
        'span'       => %w(class),
        'abbr'       => %w(title),
        'blockquote' => %w(cite data-name),
        'ol'         => %w(start reversed),
        'li'         => %w(value),
        'img'        => %w(src alt title),
        'p'          => %w(data-name),
      },

      add_attributes: {
        'a' => {
          'target' => '_blank',
        },
      },

      protocols: {
        'a'          => { 'href' => LINK_PROTOCOLS },
        'blockquote' => { 'cite' => LINK_PROTOCOLS },
      },

      transformers: [
        CLASS_WHITELIST_TRANSFORMER,
        DATA_NAME_ALLOWLIST_TRANSFORMER,
        UNSUPPORTED_HREF_TRANSFORMER,
        LINK_REL_TRANSFORMER,
      ]
    )

    MASTODON_OEMBED ||= freeze_config merge(
      RELAXED,
      elements: RELAXED[:elements] + %w(audio embed iframe source video),

      attributes: merge(
        RELAXED[:attributes],
        'audio'  => %w(controls),
        'embed'  => %w(height src type width),
        'iframe' => %w(allowfullscreen frameborder height scrolling src width),
        'source' => %w(src type),
        'video'  => %w(controls height loop width),
        'div'    => [:data]
      ),

      protocols: merge(
        RELAXED[:protocols],
        'embed'  => { 'src' => HTTP_PROTOCOLS },
        'iframe' => { 'src' => HTTP_PROTOCOLS },
        'source' => { 'src' => HTTP_PROTOCOLS }
      )
    )
  end
end
