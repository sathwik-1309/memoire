class User < ApplicationRecord
  has_many :game_users

  def self.random_shuffle(players)
    players.shuffle
  end

  def games
    self.game_users.map{|gu| gu.game}
  end
end