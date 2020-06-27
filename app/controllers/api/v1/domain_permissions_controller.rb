# frozen_string_literal: true

class Api::V1::DomainPermissionsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:domain_permissions', :'read:domain_permissions:account' }, only: :show
  before_action -> { doorkeeper_authorize! :write, :'write:domain_permissions', :'write:domain_permissions:account' }, only: [:create, :update, :destroy]
  before_action :require_user!
  before_action :set_permission, except: [:show, :create]
  after_action :insert_pagination_headers

  LIMIT = 100

  def show
    @permissions = load_account_domain_permissions
    render json: @permissions, each_serializer: REST::AccountDomainPermissionSerializer
  end

  def create
    @permission = current_account.domain_permissions.create!(domain_permission_params)
    render json: @permission, serializer: REST::AccountDomainPermissionSerializer
  end

  def update
    @permission.update!(domain_permission_params)
    render json: @permission, serializer: REST::AccountDomainPermissionSerializer
  end

  def destroy
    @permission.destroy!
    render_empty
  end

  private

  def load_account_domain_permissions
    account_domain_permissions.paginate_by_max_id(
      limit_param(LIMIT),
      params[:max_id],
      params[:since_id]
    )
  end

  def set_permission
    @permission = current_account.domain_permissions.find(params[:id])
  end

  def account_domain_permissions
    current_account.domain_permissions
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def next_path
    api_v1_domain_permissions_url pagination_params(max_id: pagination_max_id) if records_continue?
  end

  def prev_path
    api_v1_domain_permissions_url pagination_params(since_id: pagination_since_id) unless @permissions.empty?
  end

  def pagination_max_id
    @permissions.last.id
  end

  def pagination_since_id
    @permissions.first.id
  end

  def records_continue?
    @permissions.size == limit_param(LIMIT)
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end

  def domain_permission_params
    params.permit(:domain, :visibility)
  end
end
