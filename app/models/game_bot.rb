class GameBot < GameUser
  default_scope -> {where(is_bot: true)}
  belongs_to :user
  belongs_to :game

  attr_accessor :fake_name_cache

  def name
    # If fake_name_cache is not set, fetch it from meta
    @fake_name_cache ||= self.meta['fake_name']
  end

  # Custom setter for fake_name
  def fake_name=(value)
    # Set fake_name_cache to the provided value
    @fake_name_cache = value
    # Also update the value in meta
    self.meta['fake_name'] = value
  end

  def update_self_seen(card, index)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    layout['cards'][index] = Util.seen_card_memory(card, index)
    self.meta['memory']['cards']['self'][Util.get_card_number(card)] << { 'index' => index }
  end

  def update_others_seen(card, index, player_id)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == player_id}
    layout['cards'][index] = Util.seen_card_memory(card, index)
    self.meta['memory']['cards']['other'][Util.get_card_number(card)] << { 'index' => index, 'player_id' => player_id }
  end

  def replace_self_card(card, index)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    layout_memory = layout['cards']
    replaced_card = layout_memory[index]
    layout_memory[index] = Util.seen_card_memory(card, index)
    card_memory = self.meta['memory']['cards']['self']
    card_memory[Util.get_card_number(card)] << {'index' => index}
    if replaced_card['seen']
      card_memory[Util.get_card_number(replaced_card['value'])].delete({'index' => index})
    end
  end

  def remove_self_card(index)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    layout_memory = layout['cards']
    removed_card = layout_memory[index]
    layout_memory[index] = nil
    card_memory = self.meta['memory']['cards']['self']
    card_memory[Util.get_card_number(removed_card['value'])].delete({'index' => index})
  end

  def cross_offload_replace(card_hash, self_replace_index)
    self_layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    replaced_card = self_layout['cards'][self_replace_index]
    others_layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == card_hash['player_id']}
    others_layout['cards'][card_hash['index']] = replaced_card
    self.remove_self_card(self_replace_index)
  end
  
  def get_self_unknown_random_index
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    layout['cards'].shuffle.each do |card|
      return card['index'] if card.present? and card['seen'] == false
    end
    nil
  end

  def get_self_highest_card_index
    self_cards = self.meta['memory']['cards']['self']
    VALUES.reverse.each do |value|
      return self_cards[value][0] if self_cards[value].present?
    end
  end

  def find_offload_replace_index
    unknown_index = self.get_self_unknown_random_index
    return unknown_index if unknown_index.present?
    self.get_self_highest_card_index
  end

  def get_others_unknown_card
    layouts = self.meta['memory']['layout'].filter{|hash| hash['player_id'] != self.user_id}
    layouts.shuffle.each do |layout|
      unseen_card = layout['cards'].shuffle.find{|card| card != nil and card['seen'] == false }
      return unseen_card, layout['player_id'] if unseen_card.present?
    end
    nil
  end

  def trigger_self_offload(card_hash)
    url = "#{BACKEND_URL}/plays/#{self.game_id}/offload?auth_token=#{self.user.authentication_token}"
    params = { offload: {
      'type' => SELF_OFFLOAD,
      'offloaded_card_index' => card_hash['index'],
    }}
    status, res = Bot.call_api(PUT_API, url, params)
    if status
      self.remove_self_card(card_hash['index'])
      self.save!
    end
  end

  def trigger_cross_offload(card_hash)
    url = "#{BACKEND_URL}/plays/#{self.game_id}/offload?auth_token=#{self.user.authentication_token}"
    replace_index = self.find_offload_replace_index
    params = { auth_token: self.user.authentication_token,
               offload: {
                 'type' => CROSS_OFFLOAD,
                 'offloaded_card_index' => card_hash['index'],
                 'player2_id' => card_hash['player_id'],
                 'replaced_card_index' => replace_index,
               }}
    status, res = Bot.call_api(PUT_API, url, params)
    if status
      self.cross_offload_replace(card_hash, replace_index)
      self.save!
    end
  end

  def trigger_offloads
    deck_top = Util.get_card_number(self.game.used[-1])

    # self offload
    cards_to_offload = self.meta['memory']['cards']['self'][deck_top]
    cards_to_offload.each do |card_hash|
      MyWorker.perform_in(Util.random_wait(OFFLOADS).seconds, 'trigger_bot_self_offload', {'game_bot_id' => self.id, 'card_hash' => card_hash})
    end

    # cross offload
    cards_to_offload = self.meta['memory']['cards']['other'][deck_top]
    cards_to_offload.each do |card_hash|
      MyWorker.perform_in(Util.random_wait(OFFLOADS).seconds, 'trigger_bot_cross_offload', {'game_bot_id' => self.id, 'card_hash' => card_hash})
    end
  end

  def trigger_initial_view(index)
    url = "#{BACKEND_URL}/games/#{self.game_id}/view_initial?auth_token=#{self.user.authentication_token}&card_index=#{index}"
    status, res = Bot.call_api(GET_API, url)
    if status
      self.update_self_seen(res['card'], index)
      self.save!
    end
  end

  def check_for_show
    self_layout_memory = self.meta['memory']['layout'].find{|hash| hash['player_id'] == self.user_id}
    self_cards_length = self_layout_memory['cards'].filter{|card| card.present?}.length
    return false if self_cards_length >= 4
    next_lowest = 6
    self.meta['memory']['layout'].each do |hash|
      if hash['player_id'] != self.user_id
        return false if hash['cards'].length < self_cards_length
        next_lowest = hash['cards'].length if hash['cards'].length < next_lowest
      end
    end
    if self_cards_length <= next_lowest
      self_layout_memory['cards'].each do |card_hash|
        if card_hash.present?
          return false unless card_hash['seen']
          return false if NORMAL_CARD_VALUES.exclude? Util.get_card_number(card_hash['value'])
        end
      end
    end
    true
  end

  def update_others_unknown(user, index)
    layout_memory = self.meta['memory']['layout'].find{|hash| hash['player_id'] == user.id}['cards']
    discarded_card = layout_memory[index]
    if discarded_card['seen']
      layout_memory[index] = {'seen' => false, 'index' => index}
      self.meta['memory']['cards']['other'][Util.get_card_number(discarded_card['value'])].delete({'player_id'=>user.id, 'index'=>index})
    end
  end

  def update_other_self_offload(user, index)
    layout = self.meta['memory']['layout'].find{|hash| hash['player_id'] == user.id}['cards']
    offloaded_card = layout[index]
    if offloaded_card['seen']
      self.meta['memory']['cards']['other'][Util.get_card_number(offloaded_card['value'])].delete({'player_id'=>user.id, 'index'=>index})
    end
    layout[index] = nil
  end

  def update_other_cross_offload(user1, user2, offloaded_card_index, replaced_card_index)
    layout1 = self.meta['memory']['layout'].find{|hash| hash['player_id'] == user1.id}
    layout2 = self.meta['memory']['layout'].find{|hash| hash['player_id'] == user2.id}
    replaced_card = layout1['cards'][replaced_card_index]
    offloaded_card = layout2['cards'][offloaded_card_index]

    if offloaded_card['seen']
      offloaded_card_value = Util.get_card_number(offloaded_card['value'])
      if user2.id == self.user_id
        self.meta['memory']['cards']['self'][offloaded_card_value].delete({'index'=>offloaded_card_index})
      else
        self.meta['memory']['cards']['other'][offloaded_card_value].delete({'player_id'=>user2.id,'index'=>offloaded_card_index})
      end
    end

    if replaced_card['seen']
      replaced_card_value = Util.get_card_number(replaced_card['value'])
      self.meta['memory']['cards']['other'][replaced_card_value].delete({'player_id'=>user1.id,'index'=>replaced_card_index})
      if user2.id == self.user_id
        self.meta['memory']['cards']['self'][replaced_card_value] << {'index'=>offloaded_card_index}
      else
        self.meta['memory']['cards']['other'][replaced_card_value] << {'player_id'=>user2.id, 'index'=>offloaded_card_index}
      end
      layout2['cards'][offloaded_card_index] = {'seen'=> true, 'value'=>replaced_card['value'], 'index'=>offloaded_card_index}
    else
      layout2['cards'][offloaded_card_index] = {'seen'=> false, 'index'=> offloaded_card_index}
    end
    layout1['cards'][replaced_card_index] = nil
  end

  def update_swap_cards(user1, user2, card1_index, card2_index)
    layout1 = self.meta['memory']['layout'].find{|hash| hash['player_id'] == user1.id}['cards']
    layout2 = self.meta['memory']['layout'].find{|hash| hash['player_id'] == user2.id}['cards']
    card1 = layout1[card1_index]
    card2 = layout2[card2_index]
    if card1['seen'] and card2['seen']
      layout2[card2_index] = {'seen'=>true, 'value'=>card1['value'], 'index'=>card2_index}
      layout1[card1_index] = {'seen'=>true, 'value'=>card2['value'], 'index'=>card1_index}
    elsif card1['seen']
      layout2[card2_index] = {'seen'=>true, 'value'=>card1['value'], 'index'=>card2_index}
      layout1[card1_index] = {'seen'=>false, 'index'=>card1_index}
    elsif card2['seen']
      layout2[card2_index] = {'seen'=>false, 'index'=>card2_index}
      layout1[card1_index] = {'seen'=>true, 'value'=>card2['value'], 'index'=>card1_index}
    end

    card_mem = self.meta['memory']['cards']
    card1_value = Util.get_card_number(card1['value']) if card1['seen']
    card2_value = Util.get_card_number(card2['value']) if card2['seen']

    if user1.id == self.user_id and user2.id == self.user_id
      if card1['seen']
        card_mem['self'][card1_value].delete({'index'=>card1_index})
        card_mem['self'][card1_value] << {'index'=>card2_index}
      end
      if card2['seen']
        card_mem['self'][card2_value].delete({'index'=>card2_index})
        card_mem['self'][card2_value] << {'index'=>card1_index}
      end
    elsif user1.id == self.user_id
      if card1['seen']
        card_mem['self'][card1_value].delete({'index'=>card1_index})
        card_mem['other'][card1_value] << {'index'=>card2_index, 'player_id'=>user2.id}
      end
      if card2['seen']
        card_mem['other'][card2_value].delete({'index'=>card2_index, 'player_id'=>user2.id})
        card_mem['self'][card2_value] << {'index'=>card1_index}
      end
    elsif user2.id == self.user_id
      if card1['seen']
        card_mem['other'][card1_value].delete({'index'=>card1_index, 'player_id'=>user1.id})
        card_mem['self'][card1_value] << {'index'=>card2_index}
      end
      if card2['seen']
        card_mem['self'][card2_value].delete({'index'=>card2_index})
        card_mem['other'][card2_value] << {'index'=>card1_index, 'player_id'=>user1.id}
      end
    else
      if card1['seen']
        card_mem['other'][card1_value].delete({'index'=>card1_index, 'player_id'=>user1.id})
        card_mem['other'][card1_value] << {'index'=>card2_index, 'player_id'=>user2.id}
      end
      if card2['seen']
        card_mem['other'][card2_value].delete({'index'=>card2_index, 'player_id'=>user2.id})
        card_mem['other'][card2_value] << {'index'=>card1_index, 'player_id'=>user1.id}
      end
    end
  end

end