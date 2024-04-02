class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token

  rescue_from StandardError, with: :handle_internal_server_error

  # def check_current_user
  #   return if @current_user.present?
  #   if cookies[:auth_token].present? or params[:auth_token].present?
  #     auth_token = cookies[:auth_token].present? ? cookies[:auth_token] : params[:auth_token]
  #     user = User.find_by(authentication_token: auth_token)
  #     unless user.nil?
  #       @current_user = user
  #       return
  #     end
  #   end
  #   render json: {error: 'Unauthorized'}, status: 400
  # end

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

  def render_400(error_message)
    Rails.logger.error "Bad Request Error: #{error_message}"
    render json: { error: error_message }, status: 400
  end

  def render_404(error_message)
    Rails.logger.error "Resource Not Found Error: #{error_message}"
    render json: { error: error_message }, status: 404
  end

  private

  def handle_internal_server_error(exception)
    # Log the error and backtrace
    # byebug
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error(exception.backtrace.join("\n"))

    # Render a 500 error response
    render json: { error: 'Internal Server Error' }, status: 500
  end

end
