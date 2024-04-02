class LobbyController < ApplicationController
  before_action :set_current_user
  before_action :check_current_user

  def join
    lobby = Lobby.join_lobby(@current_user.id)
    render json: {lobby: lobby.slice(:id, :status, :is_filled, :players, :game_id, :timeout)}, status: 201
  end

  private
  def check_current_user
    render_400("Unauthorized") if @current_user.nil?
  end
end