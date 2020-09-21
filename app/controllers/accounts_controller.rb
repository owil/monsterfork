# frozen_string_literal: true

class AccountsController < ApplicationController
  PAGE_SIZE     = 20
  PAGE_SIZE_MAX = 200

  include AccountControllerConcern
  include SignatureAuthentication

  before_action :set_cache_headers
  before_action :set_body_classes

  before_action :require_authenticated!, if: -> { @account.require_auth? || @account.private? }

  skip_around_action :set_locale, if: -> { [:json, :rss].include?(request.format&.to_sym) }
  skip_before_action :require_functional! # , unless: :whitelist_mode?

  def show
    @without_unlisted = !@account.show_unlisted?

    respond_to do |format|
      format.html do
        use_pack 'public'
        expires_in 0, public: true unless user_signed_in? || signed_request_account.present?

        @pinned_statuses   = []
        @endorsed_accounts = unauthorized? ? [] : @account.endorsed_accounts.to_a.sample(4)
        @featured_hashtags = unauthorized? ? [] : @account.featured_tags.order(statuses_count: :desc)

        if unauthorized?
          @statuses = []
          return
        end

        @pinned_statuses = cache_collection(@account.pinned_statuses.not_local_only, Status) if show_pinned_statuses?
        @statuses        = cached_filtered_status_page
        @rss_url         = rss_url

        unless @statuses.empty?
          @older_url = older_url if @statuses.last.id > filtered_statuses.last.id
          @newer_url = newer_url if @statuses.first.id < filtered_statuses.first.id
        end
      end

      format.rss do
        return render xml: '', status: 404 if rss_disabled? || unauthorized?

        expires_in 1.minute, public: !current_account?

        @without_unlisted = true
        limit = params[:limit].present? ? [params[:limit].to_i, PAGE_SIZE_MAX].min : PAGE_SIZE
        @statuses = filtered_statuses.without_reblogs.limit(limit)
        @statuses = cache_collection(@statuses, Status)
        render xml: RSS::AccountSerializer.render(@account, @statuses, params[:tag])
      end

      format.json do
        expires_in 3.minutes, public: !current_account?
        render_with_cache json: @account, content_type: 'application/activity+json', serializer: ActivityPub::ActorSerializer, adapter: ActivityPub::Adapter, fields: restrict_fields_to
      end
    end
  end

  private

  def set_body_classes
    @body_classes = 'with-modals'
  end

  def show_pinned_statuses?
    [threads_requested?, replies_requested?, reblogs_requested?, mentions_requested?, media_requested?, tag_requested?, params[:max_id].present?, params[:min_id].present?].none?
  end

  def filtered_statuses
    return mentions_scope if mentions_requested?

    default_statuses.tap do |statuses|
      statuses.merge!(only_media_scope) if media_requested?
    end
  end

  def default_statuses
    @account.statuses.permitted_for(
      @account,
      current_account,
      include_reblogs: !(threads_requested? || replies_requested?),
      only_reblogs: reblogs_requested?,
      include_replies: replies_requested?,
      tag: tag_requested? ? params[:tag] : nil,
      public: @without_unlisted
    )
  end

  def only_media_scope
    Status.where(id: account_media_status_ids)
  end

  def account_media_status_ids
    @account.media_attachments.attached.reorder(nil).select(:status_id).distinct
  end

  def mentions_scope
    return Status.none unless current_account?

    Status.mentions_between(@account, current_account)
  end

  def username_param
    params[:username]
  end

  def rss_url
    if tag_requested?
      short_account_tag_url(@account, params[:tag], format: 'rss')
    else
      short_account_url(@account, format: 'rss')
    end
  end

  def older_url
    pagination_url(max_id: @statuses.last.id)
  end

  def newer_url
    pagination_url(min_id: @statuses.first.id)
  end

  def pagination_url(max_id: nil, min_id: nil)
    if tag_requested?
      short_account_tag_url(@account, params[:tag], max_id: max_id, min_id: min_id)
    elsif media_requested?
      short_account_media_url(@account, max_id: max_id, min_id: min_id)
    elsif threads_requested?
      short_account_threads_url(@account, max_id: max_id, min_id: min_id)
    elsif replies_requested?
      short_account_with_replies_url(@account, max_id: max_id, min_id: min_id)
    elsif reblogs_requested?
      short_account_reblogs_url(@account, max_id: max_id, min_id: min_id)
    elsif mentions_requested?
      short_account_mentions_url(@account, max_id: max_id, min_id: min_id)
    else
      short_account_url(@account, max_id: max_id, min_id: min_id)
    end
  end

  def media_requested?
    request.path.split('.').first.ends_with?('/media') && !tag_requested?
  end

  def threads_requested?
    request.path.split('.').first.ends_with?('/threads') && !tag_requested?
  end

  def replies_requested?
    return false unless current_account&.id == @account.id || @account.show_replies?

    request.path.split('.').first.ends_with?('/with_replies') && !tag_requested?
  end

  def tag_requested?
    request.path.split('.').first.ends_with?(Addressable::URI.parse("/tagged/#{params[:tag]}").normalize)
  end

  def cached_filtered_status_page
    cache_collection_paginated_by_id(
      filtered_statuses,
      Status,
      PAGE_SIZE,
      params_slice(:max_id, :min_id, :since_id)
    )
  end

  def reblogs_requested?
    request.path.split('.').first.ends_with?('/reblogs') && !tag_requested?
  end

  def mentions_requested?
    request.path.split('.').first.ends_with?('/mentions') && !tag_requested?
  end

  def params_slice(*keys)
    params.slice(*keys).permit(*keys)
  end

  def restrict_fields_to
    if current_account&.id == @account.id || (signed_request_account.present? && !blocked?)
      # Return all fields
    else
      %i(id type preferred_username inbox public_key endpoints)
    end
  end

  def blocked?
    @blocked ||= current_account && @account.blocking?(current_account)
  end

  def unauthorized?
    @unauthorized ||= blocked? || (@account.private? && !following?(@account))
  end

  def rss_disabled?
    current_user.setting_rss_disabled
  end
end
