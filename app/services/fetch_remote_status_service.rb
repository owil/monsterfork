# frozen_string_literal: true

class FetchRemoteStatusService < BaseService
  def call(url, prefetched_body = nil, on_behalf_of = nil)
    status = ActivityPub::TagManager.instance.uri_to_resource(url, Status)
    return status if status.present?

    if prefetched_body.nil?
      resource_url, resource_options = FetchResourceService.new.call(url, on_behalf_of: on_behalf_of)
    else
      resource_url     = url
      resource_options = { prefetched_body: prefetched_body }
    end

    return if resource_url.blank?

    resource_options ||= {}
    ActivityPub::FetchRemoteStatusService.new.call(resource_url, **resource_options.merge({ on_behalf_of: on_behalf_of }))
  end
end
