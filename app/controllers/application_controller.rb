class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def check_current_user
    return if @current_user.present?
    if cookies[:auth_token].present? or params[:auth_token].present?
      auth_token = cookies[:auth_token].present? ? cookies[:auth_token] : params[:auth_token]
      user = User.find_by(authentication_token: auth_token)
      unless user.nil?
        @current_user = user
        return
      end
    end
    render json: {error: 'Unauthorized'}, status: 400
  end

  def set_current_user
    if cookies[:auth_token].present? or params[:auth_token].present?
      auth_token = cookies[:auth_token].present? ? cookies[:auth_token] : params[:auth_token]
      user = User.find_by(authentication_token: auth_token)
      unless user.nil?
        @current_user = user
        return
      end
    end
  end

end
