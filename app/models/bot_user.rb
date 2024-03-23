class BotUser < GameUser
  default_scope -> {where(is_bot: true)}
  belongs_to :user
  belongs_to :game

  def update_self_seen(card, index)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    layout[index] = Util.seen_card_memory(card, index)
    self.meta['memory']['cards']['self'][Util.get_card_number(card)] << { 'index' => index }
  end

  def update_others_seen(card, index, player_id)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == player_id}
    layout[index] = Util.seen_card_memory(card, index)
    self.meta['memory']['cards']['other'][Util.get_card_number(card)] << { 'index' => index, 'player_id' => player_id }
  end

  def replace_self_card(card, index)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    replaced_card = layout[index]
    layout[index] = Util.seen_card_memory(card, index)
    card_hash = self.meta['memory']['cards']['self']
    card_hash[Util.get_card_number(card)] << {'index' => index}
    card_hash[Util.get_card_number(replaced_card)].del({'index' => index})
  end
  
  def get_self_unknown_index
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    layout.each_with_index do |card, index|
      return index unless card['seen']
    end
    nil
  end

  def get_self_unknown_indexes
    unknown_indexes = []
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    layout.each_with_index do |card, index|
      unknown_indexes << index unless card['seen']
    end
    unknown_indexes
  end

  def get_others_unknown_card
    layouts = self.meta['memory']['layout'].filter{|hash| hash['player_id'] != self.user_id}
    layouts.shuffle.each do |layout|
      unseen_card = layout['cards'].shuffle.find{|card| card != nil and card['seen'] == false }
      return unseen_card, layout['player_id'] if unseen_card.present?
    end
    nil
  end
end