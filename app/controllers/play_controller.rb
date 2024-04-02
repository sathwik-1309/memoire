class PlayController < ApplicationController
  before_action :set_current_user
  before_action :check_current_user
  before_action :check_game
  before_action :check_turn, except: [:index, :offload]
  before_action :set_game_user

  def index
    plays = @game.plays.map{|play| play.attributes.slice(:id, :game_id, :turn, :show, :card_draw, :offloads, :powerplay)}
    render json: plays, status: 200
  end

  def card_draw
    render_400("Can draw a card only in #{CARD_DRAW} stage") and return if @game.stage != CARD_DRAW
    drawn_card = @game.pile.pop
    play = Play.create!(game_id: filter_params[:game_id], turn: @current_user.id, card_draw: {'card_drawn' => drawn_card})
    @game.stage = DOR
    @game.current_play = play.id
    @game.timeout = Time.now.utc + TIMEOUT_DOR.seconds
    @game.counter += 1
    @game.save!
    ActionCable.server.broadcast(@game.channel, {message: "#{@game_user.name.titleize} drew a card!", type: CARD_DRAW, counter: @game.counter})
    MyWorker.perform_in(Util.random_wait(DOR).seconds, 'bot_actions_discard', {'game_id' => @game.id, 'card_drawn' => drawn_card})
    render json: { card_drawn: drawn_card, timeout: @game.timeout, stage: @game.stage, }, status: 200
  end

  def discard
    render_400("Can discard only in #{DOR} stage") and return if @game.stage != DOR
    render json: @game.create_discard(@current_user, filter_params['event'], @game_user), status: 200
  end

  def offload
    render_400("Can offload only in #{OFFLOADS} stage") and return if @game.stage != OFFLOADS
    play = @game.current_play
    offload = filter_params[:offload]
    gu1 = @game.game_users.find_by_user_id(@current_user.id)
    if offload['type'] == SELF_OFFLOAD
      lock_key = gu1.get_lock_key(offload['offloaded_card_index'])
      if Lock.acquire_lock(lock_key, 5)
        begin
          offloaded_card_index = offload['offloaded_card_index'].to_i
          offload_card = gu1.cards[offloaded_card_index]
          if Util.get_card_value(offload_card)[0] != Util.get_card_value(@game.used[-1])[0]
            # false offload
            nil_index = gu1.add_extra_card_or_penalty
            offload['is_correct'] = false
            @game.bot_mem_false_offload(@current_user, nil_index)
            message = "#{@game_user.name.titleize} FAILED SELF OFFLOAD on card ##{offloaded_card_index+1}"
          else
            gu1.cards[offloaded_card_index] = nil
            @game.used << offload_card
            @game.inplay.delete(offload_card)
            offload['is_correct'] = true
            @game.bot_mem_update_self_offload(@current_user, offloaded_card_index)
            message = "#{@game_user.name.titleize} did SELF OFFLOAD on card ##{offloaded_card_index+1}"
          end
          gu1.save!
        ensure
          Lock.release_lock(lock_key)
        end
      else
        render_400('Card was involved in another offload, Try again!') and return
      end

    else
      gu2 = @game.game_users.find_by_user_id(offload['player2_id'])
      lock_key1 = gu2.get_lock_key(offload['offloaded_card_index'])
      lock_key2 = gu1.get_lock_key(offload['replaced_card_index'])
      if Lock.acquire_locks(lock_key1, lock_key2, 5)
        begin
          offloaded_card_index = offload['offloaded_card_index'].to_i
          replaced_card_index = offload['replaced_card_index'].to_i
          offload_card = gu2.cards[offloaded_card_index]
          if Util.get_card_value(offload_card)[0] != Util.get_card_value(@game.used[-1])[0]
            nil_index = gu1.add_extra_card_or_penalty
            offload['is_correct'] = false
            @game.bot_mem_false_offload(@current_user, nil_index)
            message = "#{gu1.name.titleize} FAILED CROSS OFFLOAD on #{gu2.name.titleize}'s' card ##{offloaded_card_index+1}"
          else
            replaced_card = gu1.cards[replaced_card_index]
            gu1.cards[replaced_card_index] = nil
            gu2.cards[offloaded_card_index] = replaced_card
            gu2.save!
            @game.inplay.delete(offload_card)
            @game.used << offload_card
            offload['is_correct'] = true
            @game.bot_mem_update_cross_offload(@current_user, gu2.user, offloaded_card_index, replaced_card_index)
            message = "#{gu1.name.titleize} did CROSS OFFLOAD on #{gu2.name.titleize}'s' card ##{offloaded_card_index+1} and replaced with their card ##{replaced_card_index+1}"
          end
          gu1.save!
        ensure
          Lock.release_locks(lock_key1, lock_key2)
        end
      else
        render_400('Card was involved in another offload, Try again!') and return
      end
    end
    offload['player1_id'] = @current_user.id
    @game.finish_game('clean_up') if offload['is_correct'] and gu1.cards.filter{|card| card.present?}.length == 0
    play.offloads << offload if offload['is_correct']
    play.save!
    @game.counter += 1
    @game.save!
    # offload['timeout'] = @game.timeout
    ActionCable.server.broadcast(@game.channel, {message: message, type: OFFLOADS, counter: @game.counter})
    render json: offload, status: 200
  end

  def powerplay
    render_400("Can access powerplay only in #{POWERPLAY} stage") and return if @game.stage != POWERPLAY
    play = @game.current_play
    powerplay = filter_params[:powerplay]

    render_400("Powerplay type not same") and return if play.powerplay_type != powerplay['event']
    render_400("Powerplay already used for this play") and return if play.powerplay and play.powerplay['used']

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
      @game.bot_mem_update_swap_cards(gu1.user, gu2.user, card1_index, card2_index)
      ActionCable.server.broadcast(@game.channel, {message: "#{@game_user.name.titleize} SWAPPED #{gu1.name.titleize}'s card ##{powerplay['card1_index'].to_i} with #{gu2.name.titleize}'s card ##{powerplay['card2_index'].to_i}", type: POWERPLAY, counter: @game.counter})
      render json: { message: 'swapped cards successfully', timeout: @game.timeout }, status: 200
    elsif powerplay['event'] == VIEW_SELF
      gu1 = @game.game_users.find_by_user_id(@game.turn)
      view_card = gu1.cards[powerplay['view_card_index'].to_i]
      ActionCable.server.broadcast(@game.channel, {message: "#{@game_user.name.titleize} VIEWED their card ##{powerplay['view_card_index'].to_i}", type: POWERPLAY, counter: @game.counter})
      render json: { card: view_card, timeout: @game.timeout }, status: 200
    else
      gu2 = @game.game_users.find_by_user_id(powerplay['player_id'])
      view_card = gu2.cards[powerplay['view_card_index'].to_i]
      ActionCable.server.broadcast(@game.channel, {message: "#{@game_user.name.titleize} VIEWED #{gu2.name.titleize}'s card ##{powerplay['view_card_index'].to_i}", type: POWERPLAY, counter: @game.counter})
      render json: { card: view_card, timeout: @game.timeout }, status: 200
    end

  end

  def showcards
    render_400("Cannot Show after drawing card") and return if @game.stage != CARD_DRAW
    render_400("Cannot Show with 4 or more cards") and return if GameUser.find_by(game_id: @game.id, user_id: @current_user.id).cards.filter{|card| card.present?}.length >= 4

    @game.finish_game('showcards', @current_user)
    ActionCable.server.broadcast(@game.channel, {"stage": FINISHED, "id": 10})
    render json: { message: "Game is in finished state"}, status: 200
  end

  private

  def check_current_user
    render_400("Unauthorized") if @current_user.nil?
  end

  def check_game
    @game = @current_user.games.find { |game| game.id == params[:game_id].to_i }
    return if @game.present?
    render_404("Game not found")
  end

  def check_turn
    return if @current_user.id == @game.turn
    render_400("Can only trigger on your turn")
  end

  def set_game_user
    @game_user = @game.game_users.find_by_user_id(@current_user.id)
    render_400("Not part of this game") if @game_user.nil?
  end

  def filter_params
    params.permit(:game_id, :turn, :show, :player, event: {} , offload: {}, powerplay: {})
  end
end
