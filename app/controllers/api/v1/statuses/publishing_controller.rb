# frozen_string_literal: true

class Api::V1::Statuses::PublishingController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :write, :'write:statuses:publish' }
  before_action :require_user!
  before_action :set_status

  def create
    PublishStatusService.new.call(@status)

    render json: @status,
           serializer: (@status.is_a?(ScheduledStatus) ? REST::ScheduledStatusSerializer : REST::StatusSerializer),
           source_requested: truthy_param?(:source)
  end

  private

  def set_status
    @status = Status.unpublished.find(params[:status_id])
    authorize @status, :destroy?
  rescue Mastodon::NotPermittedError
    not_found
  end
end
