class User < ApplicationRecord
  has_many :game_users

  def self.random_shuffle(players)
    return players.shuffle
  end

  def games
    return self.game_users.map{|gu| gu.game}
  end
end