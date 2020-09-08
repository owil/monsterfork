# frozen_string_literal: true

module Mastodon
  module Version
    module_function

    def major
      3
    end

    def minor
      2
    end

    def patch
      0
    end

    def flags
      ''
    end

    def suffix
      '+glitch+monsterpit'
    end

    def to_a
      [major, minor, patch].compact
    end

    def to_s
      [to_a.join('.'), flags, suffix].join
    end

    def repository
      ENV.fetch('GITHUB_REPOSITORY') { 'monsterpit/monsterpit-mastodon' }
    end

    def source_base_url
      ENV.fetch('SOURCE_BASE_URL') { "https://monsterware.dev/#{repository}" }
    end

    # specify git tag or commit hash here
    def source_tag
      ENV.fetch('SOURCE_TAG', nil)
    end

    def source_url
      if source_tag
        "#{source_base_url}/tree/#{source_tag}"
      else
        source_base_url
      end
    end

    def user_agent
      @user_agent ||= "#{HTTP::Request::USER_AGENT} (Mastodon/#{Version}; +http#{Rails.configuration.x.use_https ? 's' : ''}://#{Rails.configuration.x.web_domain}/)"
    end

    def server_metadata_json
      @server_metadata_json ||= [
        {
          '@context': { 'schema': 'http://schema.org/', name: 'schema:name', value: 'schema:value' },
          type: 'PropertyValue',
          name: 'version',
          value: to_s,
        },
        {
          '@context': { 'schema': 'http://schema.org/', name: 'schema:name', value: 'schema:value' },
          type: 'PropertyValue',
          name: 'monsterpit:extensions',
          value: '2020.09.05.1',
        },
        {
          '@context': { 'schema': 'http://schema.org/', name: 'schema:name', value: 'schema:value' },
          type: 'PropertyValue',
          name: 'comment:0',
          value: "big tails can't fail",
        },
        {
          '@context': { 'schema': 'http://schema.org/', name: 'schema:name', value: 'schema:value' },
          type: 'PropertyValue',
          name: 'comment:1',
          value: 'trans rights!',
        },
        {
          '@context': { 'schema': 'http://schema.org/', name: 'schema:name', value: 'schema:value' },
          type: 'PropertyValue',
          name: 'comment:2',
          value: 'gently the kobolds',
        },
      ]
    end
  end
end
