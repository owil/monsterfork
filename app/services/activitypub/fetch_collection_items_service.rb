# frozen_string_literal: true

class ActivityPub::FetchCollectionItemsService < BaseService
  include JsonLdHelper

  COOLDOWN = 30.minutes

  # Fetches objects in a collection from a URI or hash and queues them for processing.
  # @param collection [Hash, String] Collection hash or URI
  # @param account [Account] Owner of the collection
  # @param page_limit [Integer] (10) Maximum number of pages to fetch from the collection.
  # @param item_limit [Integer] (100) Maximum number of items to fetch from the collection.
  # @option options [Boolean] :every_page (false) Whether to fetch every page in the collection,
  #   even if its items have been previously fetched.  By default, fetching will stop if all the
  #   items on any page have already been fetched.
  # @option options [Boolean] :look_ahead (false) Whether to check the next page for unfetched
  #   items if the current page's items have been previously fetched.  If there are unfetched
  #   items on the next page, fetching will continue.
  # @option options [Boolean] :skip_cooldown (false) Skip the fetch cooldown period on the a
  #   collection URI (e.g., for account migration).
  # @option options [Boolean] :include_boosts (false) Whether to skip boosts.  Including these
  #   will cause a LOT of server traffic.
  # @return [void]
  # @raise [Mastodon::RaceConditionError] Collection is already being fetched.
  # @raise [Mastodon::UnexpectedResponseError] Server returned an error while fetching a page.
  def call(collection, account, page_limit: 10, item_limit: 100, **options)
    uri = value_or_id(collection)
    return if uri.blank? || ActivityPub::TagManager.instance.local_uri?(uri)

    uri = collection['partOf'] if collection.is_a?(Hash) && collection['partOf'].present?

    @account = account
    @account = account_from_uri(uri) if @account.blank?
    set_fetch_account

    return if !options[:skip_cooldown] && Redis.current.get("fetch_collection_cooldown:#{uri}")

    collection = fetch_collection(collection)
    return if collection.blank?

    if @account.blank?
      @account = account_from_uri(collection['partOf'].presence || collection['id'])
      set_fetch_account
    end

    fetch_collection_pages(collection, page_limit, item_limit, **options)
  end

  private

  def lock_options(uri)
    { redis: Redis.current, key: "fetch_collection:#{uri}" }
  end

  def set_fetch_account
    @on_behalf_of = @account.present? ? @account.followers.local.random.first : nil
  end

  def account_from_uri(uri)
    ActivityPub::TagManager.instance.uri_to_resource(uri, Account)
  end

  def account_id_from_uri(uri)
    return if uri.blank?

    Rails.cache.fetch("account_id_from_uri:#{uri}", expires_in: 10.minutes) do
      account_from_uri(uri)&.id
    end
  end

  def valid_item?(item)
    item.is_a?(Hash) &&
      !invalid_uri?(item['id']) &&
      (item['attributedTo'].present? || item['actor'].present?) && (
        item['object'].blank? || item['type'] == 'Create' && !invalid_uri?(value_or_id(item['object']))
      )
  end

  def uri_with_account_id(item)
    object = item['object'].presence || item
    [value_or_id(object), object.is_a?(Hash) ? account_id_from_uri(object['attributedTo']) : account_id_from_uri(item['actor'])]
  end

  def invalid_uri?(uri)
    unsupported_uri_scheme?(uri) || !uri_allowed?(uri) || ActivityPub::TagManager.instance.local_uri?(uri)
  end

  def fetch_collection(collection_or_uri)
    return (collection_or_uri['id'].present? ? collection_or_uri : nil) if collection_or_uri.is_a?(Hash)
    return if !collection_or_uri.is_a?(String) || invalid_origin?(collection_or_uri)

    fetch_resource_without_id_validation(collection_or_uri, @on_behalf_of, true)
  end

  def fetch_collection_pages(collection, page_limit, item_limit, **options)
    uri = collection['partOf'].presence || collection['id']
    cooldown_key = "fetch_collection_cooldown:#{uri}"

    return if !options[:skip_cooldown] && Redis.current.get(cooldown_key)

    Redis.current.set(cooldown_key, 1, ex: COOLDOWN)

    RedisLock.acquire(lock_options(uri)) do |lock|
      raise Mastodon::RaceConditionError unless lock.acquired?

      page = CollectionPage.find_or_create_by(uri: uri, account: @account)
      every_page = options[:every_page]

      if page.next.present?
        collection = fetch_collection(page.next)
        fetch_collection_items(collection, page, page_limit, item_limit, **options)
        every_page = false
      end

      uri = collection['first'].presence || collection['id']
      page.update!(next: uri)
      collection = fetch_collection(uri) if collection['id'] != uri
      fetch_collection_items(collection, page, page_limit, item_limit, **options.merge({ every_page: every_page }))
    end
  end

  def fetch_collection_items(collection, page, page_limit, item_limit, **options)
    page_count = 0
    item_count = 0
    seen_pages = Set[page.next]
    have_items = false

    while collection.present? && collection['type'].present?
      batch = case collection['type']
              when 'Collection', 'CollectionPage'
                collection['items']
              when 'OrderedCollection', 'OrderedCollectionPage'
                collection['orderedItems']
              end

      break unless batch.is_a?(Array)

      batch_size = [batch.count, item_limit - item_count].min
      batch = batch.take(batch_size).select { |item| valid_item?(item) }.map { |item| uri_with_account_id(item) }
      result = CollectionItem.import([:uri, :account_id], batch, validate: false, on_duplicate_key_ignore: true)

      if !options[:every_page] && result.ids.blank?
        break if have_items || !options[:look_ahead]

        have_items = true
      elsif have_items
        have_items = false
      end

      item_count += result.ids.count
      page_count += 1

      next_page = collection['next']
      break unless item_count < item_limit && page_count < page_limit && next_page.present?
      break if seen_pages.include?(next_page)

      sleep [page_count.to_f / 5, 1].min

      seen_pages << next_page
      page.update!(next: next_page)
      collection = fetch_collection(next_page)
    end

    page.delete
    ActivityPub::ProcessCollectionItemsWorker.perform_async
  end
end
