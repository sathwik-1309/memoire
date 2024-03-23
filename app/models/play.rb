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

  def create_discard_or_replace(game, user)
    play = game.current_play
    event = filter_params['event']
    new_card = play.card_draw['card_drawn']
    if event['type'] == DISCARD
      play.card_draw['discarded_card'] = new_card
      discarded_card = new_card
    else
      gu = game.game_users.find_by_user_id(user.id)
      discarded_card = gu.cards[event['discarded_card_index']]
      gu.cards[event['discarded_card_index']] = new_card
      gu.save!
      play.card_draw['discarded_card'] = discarded_card
      play.card_draw['replaced_card'] = new_card
      game.inplay.delete(discarded_card)
      game.inplay << new_card
    end
    game.used << discarded_card
    play.card_draw['event'] = event['type']
    if play.is_powerplay?
      game.stage = POWERPLAY
      game.timeout = Time.now.utc + TIMEOUT_PP.seconds
    else
      game.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      game.stage = OFFLOADS
    end
    game.save!
    play.save!
    ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": user.authentication_token, "message": "stage #{game.stage}"})
    hash = {
      'discarded_card' => discarded_card,
      'timeout' => game.timeout,
      'stage' => game.stage
    }
    return hash
  end
  
end