class GameUser < ApplicationRecord
  belongs_to :user
  belongs_to :game

  def count_cards
    self.cards.map do |card|
      card.split.first == 'K' && card.split.last == '♦' ? 0 : VALUES.index(card.split.first) + 1
    end.sum
  end

end