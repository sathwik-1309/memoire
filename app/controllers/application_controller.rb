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
    render_400("Unauthorized")
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

  def render_200(msg, resp = {})
    resp["message"] = msg if msg.present?
    render :json => resp, :status => 200
  end

  def render_201(msg, resp = {})
    resp["message"] = msg if msg.present?
    render :json => resp, :status => 201
  end

  def render_400(msg, resp = {})
    resp["error"] = msg if msg.present?
    render :json => resp, :status => 400
  end

  def render_404(msg, resp = {})
    resp["error"] = msg if msg.present?
    render :json => resp, :status => 404
  end
end
