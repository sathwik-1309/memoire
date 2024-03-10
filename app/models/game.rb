class Game < ApplicationRecord
  has_many :game_users
  has_many :plays

  after_save :execute_on_stage_change

  def execute_on_stage_change
    if saved_change_to_stage?
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
        end
      end
    end
  end

  def card_draw_follow_up
    TIMEOUT_CD.times do
      return if self.stage != CARD_DRAW
      sleep(1)
    end
    self.turn = self.next_turn_player_id(self.turn)
    self.timeout = Time.now.utc + TIMEOUT_CD.seconds
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": self.stage, "id": 9})
    self.card_draw_follow_up
  end

  def dor_follow_up
    TIMEOUT_DOR.times do
      return unless self.stage == DOR
      sleep(1)
    end
    game_controller = GameController.new
    params = { game_id: self.id, event: { type: DISCARD } }
    current_user = self.turn
    game_controller.instance_variable_set(:@current_user, current_user)
    game_controller.discard_or_replace
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": self.stage, "id": 10})
  end

  def powerplay_follow_up
    TIMEOUT_PP.times do
      return unless self.stage == POWERPLAY
      sleep(1)
    end
    self.stage = OFFLOADS
    self.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": self.stage, "id": 11})
  end

  def offloads_follow_up
    sleep(TIMEOUT_OFFLOAD)
    self.stage = CARD_DRAW
    self.turn = self.next_turn_player_id(self.turn)
    self.timeout = Time.now.utc + TIMEOUT_CD.seconds
    self.save!
    ActionCable.server.broadcast(self.channel, {"timeout": self.timeout, "stage": self.stage, "id": 12})
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

  def check_start_ack
    return !self.game_users.find{|gu| gu.start_ack == false}.present?
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

  def next_turn_player_id(player_id)
    total_players = self.play_order.length
    index = self.play_order.index(player_id)
    return self.play_order[(index+1)%total_players]
  end

  def current_play
    return self.plays.last
  end
end