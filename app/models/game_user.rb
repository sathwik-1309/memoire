class GameUser < ApplicationRecord
  belongs_to :user
  belongs_to :game

  attr_accessor :game_bot_cache

  def game_bot
    # If fake_name_cache is not set, fetch it from meta
    @game_bot_cache ||= GameBot.find_by(user_id: self.user_id, game_id: self.game_id)
  end

  def game_bot=(value)
    @game_bot_cache = value
  end

  def name
    return self.game_bot.name if self.is_bot
    self.user.name
  end

  def count_cards
    self.cards.map do |card|
      if card.present? 
        card.split.first == 'K' && card.split.last == '♦' ? 0 : VALUES.index(card.split.first) + 1
      else
        0
      end
    end.sum
  end

  def offload_penalty?
    self.cards.length == 6 and self.cards.filter{|card| card.present? }.length == 6
  end

  def get_lock_key(card_index)
    "card_#{self.id}_#{card_index}"
  end

  def add_extra_card_or_penalty
    if self.offload_penalty?
      self.points += 5
      return
    end
    new_card = self.game.pile.pop
    nil_index = self.cards.index(nil)
    if nil_index
      self.cards[nil_index] = new_card
    else
      self.cards << new_card
    end
    self.game.inplay << new_card
    nil_index
  end

end