class PlayController < ApplicationController
  before_action :check_current_user
  before_action :check_game
  before_action :check_turn, except: [:index, :offload]

  def index
    plays = @game.plays.map{|play| play.attributes.slice(:id, :game_id, :turn, :show, :card_draw, :offloads, :powerplay)}
    render_200(nil,plays)
  end

  def card_draw
    render json: { error: "Can draw a card only in #{CARD_DRAW} stage" }, status: 400 and return if @game.stage != CARD_DRAW
    drawn_card = @game.pile.pop
    play = Play.create!(game_id: filter_params[:game_id], turn: @current_user.id, card_draw: {'card_drawn' => drawn_card})
    @game.stage = DOR
    @game.current_play = play.id
    @game.timeout = Time.now.utc + TIMEOUT_DOR.seconds
    @game.counter += 1
    @game.save!
    ActionCable.server.broadcast(@game.channel, {"timeout": @game.timeout, "stage": DOR, "turn": @current_user.authentication_token, "message": "stage #{DOR}"})
    MyWorker.perform_in(Util.random_wait(DOR).seconds, 'bot_actions_discard', {'game_id' => @game.id, 'card_drawn' => drawn_card})
    render json: { card_drawn: drawn_card, timeout: @game.timeout, stage: @game.stage, }, status: 200
  end

  def discard
    render json: { error: "Can discard only in #{DOR} stage" }, status: 400 and return if @game.stage != DOR
    render json: @game.create_discard(@current_user, filter_params['event']), status: 200
  end

  def offload
    render json: { error: "Can offload only in #{OFFLOADS} stage" }, status: 400 and return if @game.stage != OFFLOADS
    play = @game.current_play
    offload = filter_params[:offload]
    gu1 = @game.game_users.find_by_user_id(@current_user.id)
    if offload['type'] == SELF_OFFLOAD
      offloaded_card_index = offload['offloaded_card_index'].to_i
      offload_card = gu1.cards[offloaded_card_index]
      if Util.get_card_value(offload_card)[0] != Util.get_card_value(@game.used[-1])[0]
        # false offload
        gu1.add_extra_card_or_penalty
        offload['is_correct'] = false
      else
        gu1.cards[offloaded_card_index] = nil
        @game.used << offload_card
        @game.inplay.delete(offload_card)
        offload['is_correct'] = true
      end
      gu1.save!
    else
      offloaded_card_index = offload['offloaded_card_index'].to_i
      replaced_card_index = offload['replaced_card_index'].to_i
      gu2 = @game.game_users.find_by_user_id(offload['player2_id'])
      offload_card = gu2.cards[offloaded_card_index]
      if Util.get_card_value(offload_card)[0] != Util.get_card_value(@game.used[-1])[0]
        gu1.add_extra_card_or_penalty
        offload['is_correct'] = false
      else
        replaced_card = gu1.cards[replaced_card_index]
        gu1.cards[replaced_card_index] = nil
        gu2.cards[offloaded_card_index] = replaced_card
        gu2.save!
        @game.inplay.delete(offload_card)
        @game.used << offload_card
        offload['is_correct'] = true
      end
      gu1.save!
    end
    offload['player1_id'] = @current_user.id
    @game.finish_game('clean_up') if offload['is_correct'] and gu1.cards.filter{|card| card.present?}.length == 0
    play.offloads << offload if offload['is_correct']
    play.save!
    @game.counter += 1
    @game.save!
    # offload['timeout'] = @game.timeout
    ActionCable.server.broadcast(@game.channel, {"timeout": @game.timeout, "stage": OFFLOADS, "turn": @current_user.authentication_token, "message": 5})
    render json: offload, status: 200
  end

  def powerplay
    render json: { error: "Can access powerplay only in #{POWERPLAY} stage" }, status: 400 and return if @game.stage != POWERPLAY
    play = @game.current_play
    powerplay = filter_params[:powerplay]

    render json: { error: "Powerplay type not same" }, status: 400 and return if play.powerplay_type != powerplay['event']
    render json: { error: "Powerplay already used for this play" }, status: 400 and return if play.powerplay and play.powerplay['used']

    play.powerplay = powerplay
    play.powerplay['used'] = true
    @game.counter += 1
    play.save!

    if powerplay['event'] == SWAP_CARDS
      gu1 = @game.game_users.find_by_user_id(powerplay['player1_id'])
      gu2 = @game.game_users.find_by_user_id(powerplay['player2_id'])
      card1_index = powerplay['card1_index'].to_i
      card2_index = powerplay['card2_index'].to_i
      replace_card1 = gu1.cards[card1_index]
      replace_card2 = gu2.cards[card2_index]
      gu1.cards[card1_index] = replace_card2
      gu2.cards[card2_index] = replace_card1
      gu1.save!
      gu2.save!
      render json: { message: 'swapped cards successfully', timeout: @game.timeout }, status: 200
    elsif powerplay['event'] == VIEW_SELF
      gu1 = @game.game_users.find_by_user_id(@game.turn)
      view_card = gu1.cards[powerplay['view_card_index'].to_i]
      render json: { card: view_card, timeout: @game.timeout }, status: 200
    else
      gu2 = @game.game_users.find_by_user_id(powerplay['player_id'])
      view_card = gu2.cards[powerplay['view_card_index'].to_i]
      render json: { card: view_card, timeout: @game.timeout }, status: 200
    end

  end

  def showcards
    render json: { error: "Cannot Show after drawing card" }, status: 400 and return if @game.stage != CARD_DRAW
    render json: { error: "Cannot call show when you have 4 or more cards" }, status: 400 and return if GameUser.find_by(game_id: @game.id, user_id: @current_user.id).cards.filter{|card| card.present?}.length >= 4

    @game.finish_game('showcards', @current_user)
    ActionCable.server.broadcast(@game.channel, {"stage": FINISHED, "id": 10})
    render json: { message: "Game is in finished state"}, status: 200
  end

  private

  def check_game
    @game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
    return if @game.present?
    render json: { error: "Game not found" }, status: 404
  end

  def check_turn
    return if @current_user.id == @game.turn
    render json: { error: "Can only trigger on your turn" }, status: 400
  end

  def filter_params
    params.permit(:game_id, :turn, :show, :player, event: {} , offload: {}, powerplay: {})
  end
end
