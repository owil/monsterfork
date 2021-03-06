# frozen_string_literal: true

class ProcessHashtagsService < BaseService
  def call(status, tags = nil, extra_tags = [])
    tags ||= extra_tags | (status.local? ? Extractor.extract_hashtags(status.text) : [])
    records = []

    tag_ids = status.tag_ids.to_set

    Tag.find_or_create_by_names(tags) do |tag|
      next if tag_ids.include?(tag.id)

      status.tags << tag
      records << tag

      TrendingTags.record_use!(tag, status.account, status.created_at) if status.public_visibility?
    end

    return unless status.public_visibility?

    status.account.featured_tags.where(tag_id: records.map(&:id)).each do |featured_tag|
      featured_tag.increment(status.created_at)
    end
  end
end
