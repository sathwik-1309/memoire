class GameUser < ApplicationRecord
  belongs_to :user
  belongs_to :game

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
  end

end