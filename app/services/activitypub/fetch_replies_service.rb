# frozen_string_literal: true

class ActivityPub::FetchRepliesService < BaseService
  def call(parent_status, collection, **options)
    @account = parent_status.account
    fetch_collection_items(collection, **options)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  private

  def fetch_collection_items(collection, **options)
    ActivityPub::FetchCollectionItemsService.new.call(
      collection,
      @account,
      page_limit: 1,
      item_limit: 20,
      **options
    )
  rescue Mastodon::RaceConditionError, Mastodon::UnexpectedResponseError
    collection_uri = collection.is_a?(Hash) ? collection['id'] : collection
    return unless collection_uri.present? && collection_uri.is_a?(String)

    ActivityPub::FetchRepliesWorker.perform_async(@account.id, collection_uri)
  end
end
