class PlayController < ApplicationController
  before_action :check_current_user
  before_action :set_game, only: [:showcards]
  before_action :check_turn, only: [:showcards]
  before_action :check_cards, only: [:showcards]

  def index
    game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
    render_404('game not found') and return if game.nil?

    begin
      plays = game.plays.map do |play|
        play.attributes.slice(:id, :game_id, :turn, :show, :card_draw, :offloads, :powerplay)
      end
      render_200(nil, plays)
    rescue StandardError => e
      render_400(e.message)
    end
  end

  def card_draw
    game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
    render_404('game not found') and return if game.nil?

    render_400('Incorrect player turn') and return if game.turn != @current_user.id

    render_400("game stage is #{game.stage}: cannot draw a card") and return if game.stage != CARD_DRAW

    begin
      attributes = filter_params.slice(:game_id)
      attributes[:turn] = @current_user.id
      play = Play.new(attributes)
      drawn_card = game.pile.pop
      play.card_draw = { 'card_drawn' => drawn_card }
      play.save!
      game.stage = DOR
      game.current_play = play.id
      game.timeout = Time.now.utc + TIMEOUT_DOR.seconds
      game.save!
      ActionCable.server.broadcast(game.channel,
                                   { "timeout": game.timeout, "stage": DOR, "turn": @current_user.authentication_token,
                                     "id": 3 })
      render_200(nil, {
                   'card_drawn' => drawn_card,
                   'timeout' => game.timeout,
                   'stage' => game.stage
                 })
    rescue StandardError => e
      render_400(e.message)
    end
  end

  def discard_or_replace
    game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
    render_404('game not found') and return if game.nil?

    render_400('Incorrect player turn') and return if game.turn != @current_user.id

    render_400("game stage is #{game.stage}: cannot draw a card") and return if game.stage != DOR

    hash = game.create_discard_or_replace(@current_user, filter_params['event'])
    render_200(nil, hash)
  end

  def create_offloads
    game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
    render_404('game not found') and return if game.nil?

    render_400("game stage is #{game.stage}: cannot offload") and return if game.stage != OFFLOADS

    play = game.current_play
    offload = filter_params[:offload]
    gu1 = game.game_users.find_by_user_id(@current_user.id)
    if offload['type'] = SELF_OFFLOAD
      offload_card = gu1.cards[offload['offloaded_card_index']]
      if Util.get_card_value(offload_card)[0] != Util.get_card_value(game.used[-1])[0]
        new_card = game.pile.pop
        gu1.cards << new_card
        game.inplay << new_card
        game.pile.delete(new_card)
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
        new_card = game.pile.pop
        gu1.cards << new_card
        game.inplay << new_card
        game.pile.delete(new_card)
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
    ActionCable.server.broadcast(game.channel,
                                 { "timeout": game.timeout, "stage": game.stage,
                                   "turn": @current_user.authentication_token, "id": 5 })
    render_200(nil, offload)
    # rescue StandardError => ex
    #   render_400(ex.message)
    # end
  end

  def create_powerplay
    game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
    render_404('game not found') and return if game.nil?

    render_400('Incorrect player turn') and return if game.turn != @current_user.id

    if game.stage != POWERPLAY
      render_400("game stage is #{game.stage}: cannot exercise powerplay") and return
    end
    
    play = game.current_play
    powerplay = filter_params[:powerplay]

    if (!play.is_powerplay?)
      render_400("Is not a powerplay")
    end

    if (play.powerplay_type != powerplay['event'])
      render_400("Powerplay type not same")
    end

    if play.powerplay and play.powerplay['used']
      render_400("Powerplay used for this play")
    end
    
    play.powerplay = powerplay
    play.powerplay['used'] = true
    # game.stage = OFFLOADS
    play.save!

    if powerplay['event'] == SWAP_CARDS
      gu1 = game.game_users.find_by_user_id(@current_user.id)
      gu2 = game.game_users.find_by_user_id(powerplay['player_id'])
      replace_card1 = gu1.cards[powerplay['card1_index']]
      replace_card2 = gu2.cards[powerplay['card2_index']]
      gu1.cards[powerplay['card1_index']] = replace_card2
      gu2.cards[powerplay['card2_index']] = replace_card1
      gu1.save!
      gu2.save!
      game.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      game.save!
      # ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": @current_user.authentication_token, "id": 6})
      render_200("swapped cards successfully", {'timeout'=> game.timeout}) and return 
    elsif powerplay['event'] == VIEW_SELF
      gu1 = game.game_users.find_by_user_id(game.turn)
      view_card = gu1.cards[powerplay['view_card_index']]
      game.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      game.save!
      # ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": @current_user.authentication_token, "id": 7})
      render_200(nil, {
        'card' => view_card,
        'timeout' => game.timeout
      }) and return
    else
      gu2 = game.game_users.find_by_user_id(powerplay['player_id'])
      view_card = gu2.cards[powerplay['view_card_index']]
      game.timeout = Time.now.utc + TIMEOUT_OFFLOAD.seconds
      game.save!
      # ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": game.stage, "turn": @current_user.authentication_token, "id": 8})
      render_200(nil, {
        'card' => view_card,
        'timeout' => game.timeout
      }) and return
    end
  
  end

  def showcards
    game_users = @current_user.game_users.find_by_game_id(@game.id).game.game_users
    game_users_with_counts = game_users.map do |game_user|
      cards = game_user.cards
      count = count_cards(cards)
      [game_user, count]
    end
    winning_game_user = game_users_with_counts.min_by { |_, count| count }.first

    if winning_game_user
      render json: winning_game_user_data(winning_game_user), status: :ok
    else
      render json: { error: 'GameUser not found' }, status: :not_found
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

  private

  def set_game
    @game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
  end

  def check_turn
    return unless @current_user.id != @game.turn

    render json: { error: 'Can only be triggered on your turn' }, status: :bad_request
  end

  def check_cards
    return unless @current_user.game_users.find_by_game_id(@game.id).cards.length == 4

    render json: { error: 'Can only be triggered if you have cards <4 or >4' }, status: :bad_request
  end

  def count_cards(cards)
    cards.map do |card|
      card.split.first == 'K' && card.split.last == '♦' ? 0 : VALUES.index(card.split.first) + 1
    end.sum
  end

  def winning_game_user_data(winning_game_user)
    {
      'game_id' => winning_game_user.game_id,
      'cards' => winning_game_user.cards,
      'winning_user' => winning_game_user.user_id
    }
  end

  def filter_params
    params.permit(:game_id, :turn, :show, :player, event: {}, offload: {}, powerplay: {})
  end
end