class Game < ApplicationRecord
  has_many :game_users
  has_many :plays
  has_many :game_bots

  after_save :execute_on_stage_change

  def execute_on_stage_change
    if saved_change_to_stage?
      case self.stage
      when CARD_DRAW
        CriticalWorker.perform_in(TIMEOUT_CD.seconds, 'card_draw_follow_up', {'game_id' => self.id, 'counter' => self.counter})
      when DOR
        CriticalWorker.perform_in(TIMEOUT_DOR.seconds, 'dor_follow_up', {'game_id' => self.id, 'counter' => self.counter})
      when POWERPLAY
        CriticalWorker.perform_in(TIMEOUT_PP.seconds, 'powerplay_follow_up', {'game_id' => self.id, 'counter' => self.counter})
      when OFFLOADS
        CriticalWorker.perform_in(TIMEOUT_OFFLOAD.seconds, 'offloads_follow_up', {'game_id' => self.id, 'counter' => self.counter})
      when FINISHED
        CriticalWorker.perform_in(FINISHED_SLEEP.seconds, 'finished_follow_up', {'game_id' => self.id, 'counter' => self.counter})
      else
        # do nothing
      end
    end
  end

  def card_draw_follow_up
    self.turn = self.next_turn_player_id(self.turn)
    self.timeout = Time.now.utc + TIMEOUT_CD.seconds
    self.counter += 1
    self.save!
    CriticalWorker.perform_in(TIMEOUT_CD.seconds, 'card_draw_follow_up', {'game_id' => self.id, 'counter' => self.counter})
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": CARD_DRAW, "id": 9})
    MyWorker.perform_in(Util.random_wait(CARD_DRAW).seconds, 'bot_actions_card_draw', {'game_id' => self.id})
  end

  def dor_follow_up
    event = {}
    event['type'] = DISCARD
    self.create_discard(User.find_by_id(self.turn), event)
  end

  def powerplay_follow_up
    self.stage = OFFLOADS
    self.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
    self.counter += 1
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": OFFLOADS, "id": 11})
    MyWorker.perform_async('bot_actions_offload', {'game_id' => self.id})
  end

  def offloads_follow_up
    self.stage = CARD_DRAW
    if self.current_play.offloads.present?
      self.turn = self.next_turn_player_id(self.current_play.offloads[-1]['player1_id'])
    else
      self.turn = self.next_turn_player_id(self.turn)
    end
    self.timeout = Time.now.utc + TIMEOUT_CD.seconds
    self.counter += 1
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": CARD_DRAW, "id": 12})
    MyWorker.perform_in(Util.random_wait(CARD_DRAW).seconds, 'bot_actions_card_draw', {'game_id' => self.id})
  end

  def finished_follow_up
    self.status = DEAD
    self.counter += 1
    self.save!
    ActionCable.server.broadcast(self.channel, {"stage": DEAD, "id": 13})
  end

  def move_to_card_draw
    self.stage = CARD_DRAW
    self.timeout = Time.now.utc + TIMEOUT_CD.seconds
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": CARD_DRAW, "turn": User.find_by_id(self.turn).authentication_token, "message": "stage #{CARD_DRAW}"})
    MyWorker.perform_in(Util.random_wait(CARD_DRAW).seconds, 'bot_actions_card_draw', {'game_id' => self.id})
  end

  def self.new_pile
    full_deck = []
    SUITS.each do |suit|
      VALUES.each do |value|
        full_deck << "#{value} #{suit}"
      end
    end
    return Game.random_shuffle(full_deck)
  end

  def channel
    "game:game_channel_#{self.id}"
  end

  def started?
    self.stage != START_ACK
  end

  def finished?
    self.status == FINISHED
  end

  def dead?
    self.status == DEAD
  end

  def check_start_ack
    return !self.game_users.find{|gu| gu.status != GAME_USER_WAITING}.present?
  end

  def game_users_sorted
    self.active_users.sort_by{|gu| gu.points} + self.quit_users
  end

  def quit_users
    self.game_users.where(status: GAME_USER_QUIT).sort_by{|gu| - gu.meta['quit_time']}
  end

  def self.random_shuffle(cards)
    return cards.shuffle
  end

  def create_game_users(players)
    pile = self.pile
    inplay = []
    players.each do |player|
      if player.is_bot
        gu = GameBot.new
        gu.status = GAME_USER_WAITING
        gu.game_id = self.id
        gu.meta['memory'] = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => gu.layout_memory_init,
        }
      else
        gu = GameUser.new
        gu.game_id = self.id
      end
      gu.user_id = player.id

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

  def get_user_play_table(user)
    table = []
    index = self.play_order.index(user.id)
    total_players = self.play_order.length
    count = 0
    while count < total_players
      game_user = self.game_users.find{|gu1| gu1.user_id == self.play_order[(index+count)%total_players]}
      temp = {}
      temp['player_id'] = game_user.user_id
      temp['name'] = game_user.user.name
      temp['user_status'] = game_user.status
      if game_user.status != GAME_USER_QUIT
        if self.finished?
          temp['cards'] = game_user.cards
          # temp['finished_at'] = self.meta['game_users_sorted'].index(game_user.user_id) + 1
          # temp['points'] = game_user.points
        else
          temp['turn'] = true if self.turn == game_user.user_id
          temp['cards'] = game_user.cards.map{|card| card.present? ? 1 : 0}

        end
      end
      count += 1
      table << temp
    end
    table
  end

  def next_turn_player_id(player_id)
    total_players = self.play_order.length
    index = self.play_order.index(player_id)
    self.play_order[(index+1)%total_players]
  end

  def current_play
    self.plays.last
  end

  def create_discard(user, event)
    play = self.current_play
    new_card = play.card_draw['card_drawn']
    if event['type'] == DISCARD
      play.card_draw['discarded_card'] = new_card
      discarded_card = new_card
    else
      gu = self.game_users.find_by(user_id: user.id)
      discarded_card = gu.cards[event['discarded_card_index'].to_i]
      gu.cards[event['discarded_card_index'].to_i] = new_card
      gu.save!
      play.card_draw['discarded_card'] = discarded_card
      play.card_draw['replaced_card'] = new_card
      self.inplay.delete(discarded_card)
      self.inplay << new_card
    end
    self.used << discarded_card
    play.card_draw['event'] = event['type']
    if play.is_powerplay?
      self.stage = POWERPLAY
      self.timeout = Time.now.utc + TIMEOUT_PP.seconds
    else
      self.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      self.stage = OFFLOADS
    end
    self.counter += 1
    self.save!
    play.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": self.stage, "turn": user.authentication_token, "id": 4})

    if self.stage == POWERPLAY
      MyWorker.perform_in(Util.random_wait(POWERPLAY).seconds, 'bot_actions_powerplay', {'game_id' => self.id, 'powerplay_type' => self.current_play.powerplay_type})
    else
      MyWorker.perform_async('bot_actions_offload', {'game_id' => self.id})
    end

    hash = {
      'discarded_card' => discarded_card,
      'timeout' => self.timeout,
      'stage' => self.stage
    }
  end

  def active_users
    self.game_users.filter{ |gu| gu.status != DEAD }
  end

  def finish_game(type, user = nil)
    game_users = self.game_users
    game_users.each do |game_user|
      if game_user.status != GAME_USER_QUIT
        game_user.points += game_user.count_cards
        game_user.status = GAME_USER_FINISHED
        game_user.save!
      end
    end
    self.status = FINISHED
    self.stage = FINISHED
    self.meta['game_users_sorted'] = self.game_users_sorted.map{|gu| gu.user_id}
    if type == 'showcards'
      self.meta['show_called_by'] = {
        'player_id' => user.id,
        'name' => user.name
      }
    end
    self.meta['finish_event'] = type if type
    self.timeout = nil
    self.counter += 1
    self.save!
  end

  def get_leaderboard_hash
    arr = []
    self.meta['game_users_sorted'].each_with_index do |user_id, index|
      game_user = self.game_users.find_by_user_id(user_id)
      arr << {
        'name' => game_user.user.name,
        'player_id' => game_user.user_id,
        'finished_at' => index+1,
        'points' => game_user.points
      }
    end
    arr
  end

  # bot actions
  def bot_actions_card_draw
    game_bot = self.game_bots.find_by(user_id: self.turn)
    return if game_bot.nil?
    if game_bot.check_for_show
      url = "#{BACKEND_URL}/plays/#{self.id}/showcards?auth_token=#{game_bot.user.authentication_token}"
      status, res = Bot.call_api(PUT_API, url)
    else
      url = "#{BACKEND_URL}/plays/#{self.id}/card_draw?auth_token=#{game_bot.user.authentication_token}"
      status, res = Bot.call_api(POST_API, url)
    end
  end

  def bot_actions_initial_view
    self.game_bots.each do |game_bot|
      indexes = [0,1,2,3].sample(2)
      time1 = Util.random_wait(INITIAL_VIEW)

      # first card view
      MyWorker.perform_in(time1.seconds, 'trigger_bot_initial_view', {'game_bot_id' => game_bot.id, 'index'=> indexes[0]})

      # second card view
      time2 = Util.random_wait(INITIAL_VIEW)
      MyWorker.perform_in((time1+time2).seconds, 'trigger_bot_initial_view', {'game_bot_id' => game_bot.id, 'index'=> indexes[1]})
    end
  end

  def bot_actions_discard(card_drawn)
    game_bot = self.game_bots.find_by(user_id: self.turn)
    return if game_bot.nil?
    url = "#{BACKEND_URL}/plays/#{self.id}/discard?auth_token=#{game_bot.user.authentication_token}"
    if POWERPLAY_CARD_VALUES.include? Util.get_card_number(card_drawn)
      params = {
        event: {
          'type' => DISCARD,
        }}
      status, res = Bot.call_api(PUT_API, url, params)
    else
      unknown_card_index = game_bot.get_self_unknown_random_index
      #TODO: if unknown_card_index not present, discard highest index which is greater than card_drawn and remove below ThreadError
      return unless unknown_card_index.present?
      params = {
        event: {
          'type' => REPLACE,
          'discarded_card_index' => unknown_card_index
        }}
      status, res = Bot.call_api(PUT_API, url, params)
      if status
        game_bot.replace_self_card(card_drawn, unknown_card_index)
        game_bot.save!
      end
    end
  end

  def bot_actions_powerplay(powerplay_type)
    game_bot = self.game_bots.find_by(user_id: self.turn)
    return if game_bot.nil?
    case powerplay_type
    when VIEW_SELF
      unknown_index = game_bot.get_self_unknown_random_index
      return unless unknown_index.present?
      url = "#{BACKEND_URL}/plays/#{self.id}/powerplay?auth_token=#{game_bot.user.authentication_token}"
      params = { powerplay: {
        'event' => VIEW_SELF,
        'view_card_index' => unknown_index
      }}
      status, res = Bot.call_api(PUT_API, url, params)
      if status
        game_bot.update_self_seen(res['card'], unknown_index)
        game_bot.save!
      end
    when VIEW_OTHERS
      unknown_card, player_id = game_bot.get_others_unknown_card
      return unless unknown_card.present?
      url = "#{BACKEND_URL}/plays/#{self.id}/powerplay?auth_token=#{game_bot.user.authentication_token}"
      params = { powerplay: {
        'event' => VIEW_OTHERS,
        'view_card_index' => unknown_card['index'],
        'player_id' => player_id,
      }}
      status, res = Bot.call_api(PUT_API, url, params)
      if status
        game_bot.update_others_seen(res['card'], unknown_card['index'], player_id)
        game_bot.save!
      end
    when SWAP_CARDS
      #TODO: workout the logic
    else
      #nothing
    end
  end

  def bot_actions_offload
    self.game_bots.each do |game_bot|
      MyWorker.perform_async('trigger_bot_offloads', {'game_bot_id' => game_bot.id})
    end
  end

end