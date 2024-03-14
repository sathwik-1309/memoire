class PlayController < ApplicationController
  before_action :check_current_user
  before_action :set_game, only: [:showcards]
  before_action :check_turn, only: [:showcards]
  before_action :check_cards, only: [:showcards]

  def index
    game = @current_user.games.find{|game| game.id == params[:game_id].to_i}
    if game.nil?
      render_404("game not found") and return
    end
    begin
      plays = game.plays.map{|play| play.attributes.slice(:id, :game_id, :turn, :show, :card_draw, :offloads, :powerplay)}
      render_200(nil,plays)
    rescue StandardError => ex
      render_400(ex.message)
    end
  end

  def card_draw
    game =  @current_user.games.find{|game| game.id == params[:game_id].to_i}
    if game.nil?
      render_404("game not found") and return
    end

    if game.turn != @current_user.id
      render_400("Incorrect player turn") and return
    end

    if game.stage != CARD_DRAW
      render_400("game stage is #{game.stage}: cannot draw a card") and return
    end

    begin
      attributes = filter_params.slice(:game_id)
      attributes[:turn] = @current_user.id
      play = Play.new(attributes)
      drawn_card = game.pile.pop
      play.card_draw = {'card_drawn' => drawn_card}
      play.save!
      game.stage = DOR
      game.current_play = play.id
      game.timeout = Time.now.utc + TIMEOUT_DOR.seconds
      game.save!
      ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": DOR, "turn": @current_user.authentication_token, "id": 3})
      render_200(nil,{
        'card_drawn' => drawn_card,
        'timeout' => game.timeout,
        'stage' => game.stage
      })

    rescue StandardError => ex
      render_400(ex.message)
    end

  end

  def discard_or_replace
    game =  @current_user.games.find{|game| game.id == params[:game_id].to_i}
    if game.nil?
      render_404("game not found") and return
    end

    if game.turn != @current_user.id
      render_400("Incorrect player turn") and return
    end

    if game.stage != DOR
      render_400("game stage is #{game.stage}: cannot draw a card") and return
    end
    hash = game.create_discard_or_replace(@current_user, filter_params['event'])
    render_200(nil, hash)
  end

  def create_offloads
    game =  @current_user.games.find{|game| game.id == params[:game_id].to_i}
    if game.nil?
      render_404("game not found") and return
    end

    if game.stage != OFFLOADS
      render_400("game stage is #{game.stage}: cannot offload") and return
    end

    # begin
      play = game.current_play
      offload = filter_params[:offload]
      gu1 = game.game_users.find_by_user_id(@current_user.id)
      if offload['type'] == SELF_OFFLOAD
        offload_card = gu1.cards[offload['offloaded_card_index']]
        if Util.get_card_value(offload_card)[0] != Util.get_card_value(game.used[-1])[0]
          # false offload
          gu1.add_extra_card_or_penalty
          offload['is_correct'] = false
        else
          gu1.cards[offload['offloaded_card_index']] = nil
          game.used << offload_card
          game.inplay.delete(offload_card)
          offload['is_correct'] = true
        end
        gu1.save!
      else
        gu2 = game.game_users.find_by_user_id(offload['player2_id'])
        offload_card = gu2.cards[offload['offloaded_card_index']]
        if Util.get_card_value(offload_card)[0] != Util.get_card_value(game.used[-1])[0]
          # false offload
          gu1.add_extra_card_or_penalty
          offload['is_correct'] = false
        else
          replaced_card = gu1.cards[offload['replaced_card_index']]
          gu1.cards[offload['replaced_card_index']] = nil
          gu2.cards[offload['offloaded_card_index']] = replaced_card
          gu2.save!
          game.inplay.delete(offload_card)
          game.used << offload_card
          offload['is_correct'] = true
        end
        gu1.save!
      end
      offload['player1_id'] = @current_user.id
      play.offloads = [] if play.offloads.nil?
      play.offloads << offload
      play.save!
      game.save!
      offload['timeout'] = game.timeout
      ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": @current_user.authentication_token, "id": 5})
      render_200(nil, offload)
    # rescue StandardError => ex
    #   render_400(ex.message)
    # end
  end

  def create_powerplay
    game =  @current_user.games.find{|game| game.id == params[:game_id].to_i}
    if game.nil?
      render_404("game not found") and return
    end

    if game.turn != @current_user.id
      render_400("Incorrect player turn") and return
    end

    if game.stage != POWERPLAY
      render_400("game stage is #{game.stage}: cannot exercise powerplay") and return
    end

    play = game.current_play
    powerplay = filter_params[:powerplay]

    if (!play.is_powerplay?)
      render_400("Is not a powerplay") and return
    end

    if (play.powerplay_type != powerplay['event'])
      render_400("Powerplay type not same") and return
    end

    if play.powerplay and play.powerplay['used']
      render_400("Powerplay used for this play") and return
    end

    play.powerplay = powerplay
    play.powerplay['used'] = true
    # game.stage = OFFLOADS
    play.save!

    if powerplay['event'] == SWAP_CARDS
      gu1 = game.game_users.find_by_user_id(powerplay['player1_id'])
      gu2 = game.game_users.find_by_user_id(powerplay['player2_id'])
      replace_card1 = gu1.cards[powerplay['card1_index']]
      replace_card2 = gu2.cards[powerplay['card2_index']]
      gu1.cards[powerplay['card1_index']] = replace_card2
      gu2.cards[powerplay['card2_index']] = replace_card1
      gu1.save!
      gu2.save!
      game.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      game.stage = OFFLOADS
      game.save!
      ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": OFFLOADS, "turn": @current_user.authentication_token, "id": 6})
      render_200("swapped cards successfully", {'timeout'=> game.timeout}) and return
    elsif powerplay['event'] == VIEW_SELF
      gu1 = game.game_users.find_by_user_id(game.turn)
      view_card = gu1.cards[powerplay['view_card_index']]
      # game.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      # game.save!
      # ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": @current_user.authentication_token, "id": 7})
      render_200(nil, {
        'card' => view_card,
        'timeout' => game.timeout
      }) and return
    else
      gu2 = game.game_users.find_by_user_id(powerplay['player_id'])
      view_card = gu2.cards[powerplay['view_card_index']]
      # game.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      # game.save!
      # ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": @current_user.authentication_token, "id": 8})
      render_200(nil, {
        'card' => view_card,
        'timeout' => game.timeout
      }) and return
    end

  end

  def close_powerplay
    game =  @current_user.games.find{|game| game.id == params[:game_id].to_i}
    if game.nil?
      render_404("game not found") and return
    end

    if game.turn != @current_user.id
      render_400("Incorrect player turn") and return
    end

    if game.stage != POWERPLAY
      render_400("game stage is #{game.stage}: cannot exercise powerplay") and return
    end

    game.stage = OFFLOADS
    game.save!
    ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": @current_user.authentication_token, "id": 7})
    render_200("Ack")
  end

  def showcards
    game_users = @game.game_users
    game_users.each do |game_user|
      game_user.points += game_user.count_cards
      game_user.status = GAME_USER_FINISHED
      game_user.save!
    end
    @game.status = FINISHED
    @game.stage = FINISHED
    @game.meta['game_users_sorted'] = @game.game_users_sorted.map{|gu| gu.user_id}
    @game.meta['show_called_by'] = {
      'player_id' => @current_user.id,
      'name' => @current_user.name
    }
    @game.timeout = nil
    @game.save!
    puts "---------"
    puts @game.status
    puts "---------"
    ActionCable.server.broadcast(@game.channel, {"stage": FINISHED, "id": 10})
    render_200("Game is in finished state")
  end
  private

  def set_game
    @game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
  end

  def check_turn
    return unless @current_user.id != @game.turn
    render_400("Can only be triggered on your turn") and return
  end

  def check_cards
    return if GameUser.find_by(game_id: @game.id, user_id: @current_user.id).cards.filter{|card| card.present?}.length < 4
    render_400("Cannot call show when you have 4 or more cards") and return
  end

  def filter_params
    params.permit(:game_id, :turn, :show, :player, event: {} , offload: {}, powerplay: {})
  end
end
