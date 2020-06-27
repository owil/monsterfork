# frozen_string_literal: true

class Api::V1::Accounts::StatusesController < Api::BaseController
  before_action -> { authorize_if_got_token! :read, :'read:statuses' }
  before_action :set_account

  after_action :insert_pagination_headers, unless: -> { truthy_param?(:pinned) }

  def index
    @statuses = load_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_account&.id)
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def owner?
    @account.id == current_account&.id
  end

  def load_statuses
    cached_account_statuses
  end

  def cached_account_statuses
    statuses = truthy_param?(:pinned) ? pinned_scope : permitted_account_statuses
    statuses.merge!(only_media_scope) if truthy_param?(:only_media)

    cache_collection_paginated_by_id(
      statuses,
      Status,
      limit_param(DEFAULT_STATUSES_LIMIT),
      params_slice(:max_id, :since_id, :min_id)
    )
  end

  def permitted_account_statuses
    return mentions_scope if truthy_param?(:mentions)
    return Status.none if unauthorized?

    @account.statuses.permitted_for(
      @account,
      current_account,
      include_semiprivate: true,
      include_reblogs: include_reblogs?,
      include_replies: include_replies?,
      only_reblogs: only_reblogs?,
      only_replies: only_replies?,
      include_unpublished: owner?,
      tag: params[:tagged]
    )
  end

  def only_media_scope
    Status.joins(:media_attachments).merge(@account.media_attachments.reorder(nil)).group(:id)
  end

  def unauthorized?
    (@account.private && !following?(@account)) || (@account.require_auth && !current_account?)
  end

  def include_reblogs?
    params[:include_reblogs].present? ? truthy_param?(:include_reblogs) : !truthy_param?(:exclude_reblogs)
  end

  def include_replies?
    return false unless owner? || @account.show_replies?

    params[:include_replies].present? ? truthy_param?(:include_replies) : !truthy_param?(:exclude_replies)
  end

  def only_reblogs?
    truthy_param?(:only_reblogs).presence || false
  end

  def only_replies?
    return false unless owner? || @account.show_replies?

    truthy_param?(:only_replies).presence || false
  end

  def mentions_scope
    return Status.none unless current_account?

    Status.mentions_between(@account, current_account)
  end

  def pinned_scope
    return Status.none if @account.blocking?(current_account)

    @account.pinned_statuses
  end

  def pagination_params(core_params)
    params.slice(:limit, :only_media, :include_replies, :exclude_replies, :only_replies, :include_reblogs, :exclude_reblogs, :only_relogs, :mentions)
          .permit(:limit, :only_media, :include_replies, :exclude_replies, :only_replies, :include_reblogs, :exclude_reblogs, :only_relogs, :mentions)
          .merge(core_params)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def next_path
    api_v1_account_statuses_url pagination_params(max_id: pagination_max_id) if records_continue?
  end

  def prev_path
    api_v1_account_statuses_url pagination_params(min_id: pagination_since_id) unless @statuses.empty?
  end

  def records_continue?
    @statuses.size == limit_param(DEFAULT_STATUSES_LIMIT)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
