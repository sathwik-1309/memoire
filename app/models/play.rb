class Play < ApplicationRecord
  belongs_to :game

  def is_powerplay?
    # return false if self.card_draw.nil?
    card_drawn = self.card_draw['card_drawn']
    # return false if card_drawn.nil?
    return false if card_drawn != self.card_draw['discarded_card']
    if POWERPLAY_CARD_VALUES.include? Util.get_card_value(card_drawn)[0]
      return true
    end
    return false
  end

  def powerplay_type
    card_drawn = Util.get_card_value(self.card_draw['card_drawn'])[0]
    if ['7','8'].include? card_drawn
      return VIEW_SELF
    elsif ['9','10'].include? card_drawn
      return VIEW_OTHERS
    elsif ['J','Q'].include? card_drawn
      return SWAP_CARDS
    else
      raise StandardError.new("no powerplay type for #{card_drawn}")
    end
  end
  
end