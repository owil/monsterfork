# frozen_string_literal: true

class RemoveHashtagsService < BaseService
  def call(status, tags)
    tags = status.tags.matching_name(tags) if tags.is_a?(Array)

    status.account.featured_tags.where(tag: tags).each do |featured_tag|
      featured_tag.decrement(status.id)
    end

    if status.distributable?
      delete_payload = Oj.dump(event: :delete, payload: status.id.to_s)
      tags.pluck(:name).each do |hashtag|
        redis.publish("timeline:hashtag:#{hashtag.mb_chars.downcase}", delete_payload)
        redis.publish("timeline:hashtag:#{hashtag.mb_chars.downcase}:local", delete_payload) if status.local?
      end
    end

    status.tags -= tags
  end
end
