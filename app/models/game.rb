class Game < ApplicationRecord
  has_many :game_users
  has_many :plays

  def self.new_pile
    full_deck = []
    SUITS.each do |suit|
      VALUES.each do |value|
        full_deck << "#{value} #{suit}"
      end
    end
    return Game.random_shuffle(full_deck)
  end

  def self.random_shuffle(cards)
    return cards.shuffle
  end

  def create_game_users(players)
    pile = self.pile
    inplay = []
    players.each do |player|
      gu = GameUser.new
      gu.user_id = player.id
      gu.game_id = self.id
      cards = pile[..3]
      inplay += cards
      gu.cards = cards
      gu.save!
      pile = pile[4..]
    end
    self.pile = pile
    self.inplay = inplay
    self.save!
  end

  def update_turn_from_offload(player_id)
    total_players = self.play_order.length
    index = self.play_order.index(player_id)
    return self.play_order[(index+1)%total_players]
  end

  def current_play
    return self.plays.last
  end
end