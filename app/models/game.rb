class Game < ApplicationRecord
  has_many :game_users
  has_many :plays

  after_save :execute_on_stage_change

  def execute_on_stage_change
    if saved_change_to_stage?
      begin
        Thread.new do
          case self.stage
          when CARD_DRAW
            self.card_draw_follow_up
          when DOR
            self.dor_follow_up
          when POWERPLAY
            self.powerplay_follow_up
          when OFFLOADS
            self.offloads_follow_up
          when FINISHED
            self.finished_follow_up
          end
        end
      rescue StandardError => ex
        #TODO: logging
      end
    end
  end

  def card_draw_follow_up
    TIMEOUT_CD.times do
      return if self.reload.status != ONGOING or self.stage != CARD_DRAW
      sleep(1)
    end
    self.turn = self.next_turn_player_id(self.turn)
    self.timeout = Time.now.utc + TIMEOUT_CD.seconds
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": CARD_DRAW, "id": 9})
    ThreadAction.bot_actions_card_draw(self)
    self.card_draw_follow_up
  end

  def dor_follow_up
    TIMEOUT_DOR.times do
      return if self.reload.status != ONGOING or self.stage != DOR
      sleep(1)
    end
    event = {}
    event['type'] = DISCARD
    self.create_discard_or_replace(User.find_by_id(self.turn), event)
  end

  def powerplay_follow_up
    TIMEOUT_PP.times do
      return if self.reload.status != ONGOING or self.stage != POWERPLAY
      sleep(1)
    end
    self.stage = OFFLOADS
    self.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": OFFLOADS, "id": 11})
  end

  def offloads_follow_up
    sleep(TIMEOUT_OFFLOAD)
    return if self.reload.status != ONGOING
    self.stage = CARD_DRAW
    if self.current_play.offloads.present?
      self.turn = self.next_turn_player_id(self.current_play.offloads[-1]['player1_id'])
    else
      self.turn = self.next_turn_player_id(self.turn)
    end
    self.timeout = Time.now.utc + TIMEOUT_CD.seconds
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": CARD_DRAW, "id": 12})
    ThreadAction.bot_actions_card_draw(self)
  end

  def finished_follow_up
    sleep(FINSIHED_SLEEP)
    self.status = DEAD
    self.save!
    ActionCable.server.broadcast(self.channel, {"stage": DEAD, "id": 13})
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
        gu = BotUser.new
        gu.status = GAME_USER_WAITING
        gu.meta['memory'] = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => gu.layout_memory_init,
        }
      else
        gu = GameUser.new
      end
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

  def next_turn_player_id(player_id)
    total_players = self.play_order.length
    index = self.play_order.index(player_id)
    return self.play_order[(index+1)%total_players]
  end

  def current_play
    return self.plays.last
  end

  def create_discard_or_replace(user, event)
    play = self.current_play
    new_card = play.card_draw['card_drawn']
    if event['type'] == DISCARD
      play.card_draw['discarded_card'] = new_card
      discarded_card = new_card
    else
      gu = self.game_users.find_by_user_id(user.id)
      discarded_card = gu.cards[event['discarded_card_index']]
      gu.cards[event['discarded_card_index']] = new_card
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
    self.save!
    play.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": self.stage, "turn": user.authentication_token, "id": 4})
    hash = {
      'discarded_card' => discarded_card,
      'timeout' => self.timeout,
      'stage' => self.stage
    }
    return hash
  end

  def active_users
    self.game_users.filter{ |gu| gu.status != DEAD }
  end

  def bot_users
    self.game_users.where(is_bot: true)
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
    self.meta['finish_event'] = type
    self.timeout = nil
    self.save!
  end

end