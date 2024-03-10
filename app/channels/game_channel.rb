class GameChannel < ApplicationCable::Channel
  def subscribed
    # @game_id = params[:game_id]
    stream_for "game_channel_#{params[:game_id]}"
  end

end
