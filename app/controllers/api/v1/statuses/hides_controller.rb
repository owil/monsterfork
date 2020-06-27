# frozen_string_literal: true

class Api::V1::Statuses::HidesController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :write, :'write:mutes' }
  before_action :require_user!
  before_action :set_status

  def create
    MuteStatusService.new.call(current_account, @status)
    render json: @status, serializer: REST::StatusSerializer
  end

  def destroy
    current_account.unmute_status!(@status)
    render json: @status, serializer: REST::StatusSerializer
  end

  private

  def set_status
    @status = Status.find(params[:status_id])
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    not_found
  end
end
