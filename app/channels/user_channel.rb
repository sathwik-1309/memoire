class UserChannel < ApplicationCable::Channel
  def subscribed
    stream_from USER_CHANNEL
  end

  # Other channel methods...
end
