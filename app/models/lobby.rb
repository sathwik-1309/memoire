class Lobby < ApplicationRecord
  MAX_RETRY_COUNT = 10

  def follow_up
    return if self.status == FINISHED
    key = "lobby_#{self.id}"
    retry_count = 0
    while retry_count < MAX_RETRY_COUNT
      if Lock.acquire_lock(key, 5)
        self.game_id = self.create_new_game
        self.status = FINISHED
        self.save!
        ActionCable.server.broadcast(self.channel, {game_id: self.game_id, status: self.status})
        return
      else
        retry_count += 1
        sleep(0.1)
      end
    end
    raise StandardError.new('Lobby deadlock')
  end

  def channel
    "lobby:lobby_channel_#{self.id}"
  end

  def create_new_game
    players = User.where(id: self.players)
    if players.length < 4
      bots = Util.pick_n_random_items(Bot.all, 4-players.length)
      players += bots
    end
    players = User.random_shuffle(players)

    game = Game.create!(status: START_ACK,
                        pile: Game.new_pile,
                        play_order: players.map{|player| player.id},
                        turn: players[0].id)
    game.create_game_users(players)
    game.id
  end

  def self.create_new_lobby(user_id)
    lobby = Lobby.create(players: [user_id], timeout: Time.now.utc + TIMEOUT_LOBBY)
    EventMachine.add_timer(TIMEOUT_LOBBY) do
      lobby.follow_up
    end
    return lobby
  end

  def self.join_lobby(user_id)
    retry_count = 0
    lobby = Lobby.last
    return Lobby.create_new_lobby(user_id) if lobby.nil? or lobby.status == FINISHED

    key = "lobby_#{lobby.id}"
    while retry_count < MAX_RETRY_COUNT
      if Lock.acquire_lock(key, 5)
        begin
          if lobby.is_filled
            return Lobby.create_new_lobby(user_id)
          else
            lobby.players << user_id
            if lobby.players.length >= 4
              lobby.is_filled = true
            end
          end
        ensure
          lobby.save!
          Lock.release_lock(key)
          lobby.follow_up if lobby.is_filled
          return lobby
        end
      else
        retry_count += 1
        sleep(0.1)
      end
    end
    return Lobby.create_new_lobby(user_id)
  end

end