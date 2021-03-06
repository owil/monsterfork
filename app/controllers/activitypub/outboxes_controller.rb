# frozen_string_literal: true

class ActivityPub::OutboxesController < ActivityPub::BaseController
  LIMIT = 20

  include SignatureVerification
  include AccountOwnedConcern

  before_action :require_signature!, if: :authorized_fetch_mode?
  before_action :require_following!, if: -> { @account.private? }
  before_action :set_statuses
  before_action :set_cache_headers

  def show
    expires_in(page_requested? ? 0 : 3.minutes, public: public_fetch_mode? && !(current_account.present? && page_requested?))
    render json: outbox_presenter, serializer: ActivityPub::OutboxSerializer, adapter: ActivityPub::Adapter, content_type: 'application/activity+json', domain: current_account&.domain
  end

  private

  def outbox_presenter
    if page_requested?
      ActivityPub::CollectionPresenter.new(
        id: outbox_url(page_params),
        type: :ordered,
        part_of: outbox_url,
        prev: prev_page,
        next: next_page,
        items: @statuses
      )
    else
      ActivityPub::CollectionPresenter.new(
        id: account_outbox_url(@account),
        type: :ordered,
        size: @account.statuses_count,
        first: outbox_url(page: true),
        last: outbox_url(page: true, min_id: 0)
      )
    end
  end

  def outbox_url(**kwargs)
    if params[:account_username].present?
      account_outbox_url(@account, **kwargs)
    else
      instance_actor_outbox_url(**kwargs)
    end
  end

  def next_page
    account_outbox_url(@account, page: true, max_id: @statuses.last.id) if @statuses.size == LIMIT
  end

  def prev_page
    account_outbox_url(@account, page: true, min_id: @statuses.first.id) unless @statuses.empty?
  end

  def permitted_account_statuses
    @account.statuses.permitted_for(
      @account,
      current_account,
      include_replies: true,
      include_reblogs: true,
      public: !(owner? || follower?),
      exclude_local_only: true
    )
  end

  def owner?
    return @owner if defined?(@owner)

    @owner   = @account.id == current_account&.id
    @owner ||= @account.moved_to_account_id == current_account&.id if @account.moved_to_account_id.present?
    @owner
  end

  def follower?
    @following ||= current_account&.following?(@account)
  end

  def mutual_follower?
    follower? && @account.following?(current_account)
  end

  def set_statuses
    return unless page_requested?

    @statuses = cache_collection_paginated_by_id(
      permitted_account_statuses,
      Status,
      LIMIT,
      params_slice(:max_id, :min_id, :since_id)
    )
  end

  def page_requested?
    truthy_param?(:page)
  end

  def page_params
    { page: true, max_id: params[:max_id], min_id: params[:min_id] }.compact
  end

  def set_account
    @account = params[:account_username].present? ? Account.find_local!(username_param) : Account.representative
  end
end
