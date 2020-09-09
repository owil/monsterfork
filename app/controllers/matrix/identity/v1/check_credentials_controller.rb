# frozen_string_literal: true

class Matrix::Identity::V1::CheckCredentialsController < Matrix::BaseController
  def create
    matrix_profile = matrix_profile_json
    return render json: fail_json if matrix_profile.blank?

    render json: matrix_profile
  rescue ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    render json: fail_json
  end

  private

  def resource_params
    params.require(:user).permit(:id, :password)
  end

  def matrix_domains
    ENV.fetch('MATRIX_AUTH_DOMAINS', '').delete(',').split.to_set
  end

  def matrix_profile_json
    user_params = resource_params
    return unless user_params[:id].present? && user_params[:password].present? && user_params[:id][0] == '@'

    (username, domain) = user_params[:id].downcase.split(':', 2)
    return unless matrix_domains.include?(domain)

    user = User.find_by_lower_username!(username[1..-1])
    return unless user.valid_password?(user_params[:password])

    {
      auth: {
        success: true,
        mxid: "@#{username}:#{domain}",
        profile: {
          display_name: user.account.display_name.presence || user.username,
          three_pids: [
            {
              medium: 'email',
              address: user.email,
            },
          ]
        }
      }
    }
  end

  def fail_json
    { auth: { success: false } }
  end
end
