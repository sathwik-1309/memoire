class LobbyChannel < ApplicationCable::Channel
  def subscribed
    # @game_id = params[:game_id]
    stream_for "lobby_channel_#{params[:lobby_id]}"
  end

end
