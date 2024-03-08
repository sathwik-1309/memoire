class PlayController < ApplicationController
  before_action :check_current_user
  
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
      game.save!
      render_200(nil,{
        'card_drawn' => drawn_card
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

    begin
      play = game.current_play
      event = filter_params['event']
      new_card = play.card_draw['card_drawn']
      if event['type'] == DISCARD
        play.card_draw['discarded_card'] = new_card
        discarded_card = new_card
      else
        gu = game.game_users.find_by_user_id(@current_user.id)
        discarded_card = gu.cards[event['discarded_card_index']-1]
        gu.cards[event['discarded_card_index']-1] = new_card
        gu.save!
        play.card_draw['discarded_card'] = discarded_card
        play.card_draw['replaced_card'] = new_card
        game.inplay.delete(discarded_card)
        game.inplay << new_card
      end
      game.used << discarded_card
      play.card_draw['event'] = event['type']
      if POWERPLAY_CARD_VALUES.include? Util.get_card_value(play.card_draw['card_drawn'])[0]
        game.stage = POWERPLAY
      else
        game.stage = OFFLOADS
      end
      
      game.save!
      play.save!
      render_200(nil, {
        'discarded_card' => discarded_card
      })
    rescue StandardError => ex
      render_400(ex.message)
    end
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
      if offload['type'] = SELF_OFFLOAD
        offload_card = gu1.cards[offload['offloaded_card_index']-1]
        if Util.get_card_value(offload_card)[0] != Util.get_card_value(game.used[-1])[0]
          new_card = game.pile.pop
          gu1.cards << new_card
          game.inplay << new_card
          game.pile.delete(new_card)
          offload['is_correct'] = false
        else
          gu1.cards[offload['offloaded_card_index']-1] = nil
          game.used << offload_card
          game.inplay.delete(offload_card)
          offload['is_correct'] = true
        end
        gu1.save!
      else
        gu2 = game.game_users.find_by_user_id(offload['player2_id'])
        offload_card = gu2.cards[offload['offloaded_card_index']-1]
        if Util.get_card_value(offload_card)[0] != Util.get_card_value(game.used[-1])[0]
          new_card = game.pile.pop
          gu1.cards << new_card
          game.inplay << new_card
          game.pile.delete(new_card)
          offload['is_correct'] = false
        else
          replaced_card = gu1.cards[offload['replaced_card_index']-1]
          gu1.cards[offload['replaced_card_index']-1] = nil
          gu2.cards[offload['offloaded_card_index']-1] = replaced_card
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

    begin
      play = game.current_play
      powerplay = filter_params[:powerplay]
      play.powerplay = powerplay
      game.stage = OFFLOADS
      game.save!
      play.save!

      if powerplay['event'] == SWAP_CARDS
        gu1 = game.game_users.find_by_user_id(@current_user.id)
        gu2 = game.game_users.find_by_user_id(powerplay['player_id'])
        replace_card1 = gu1.cards[powerplay['card1_index']-1]
        replace_card2 = gu2.cards[powerplay['card2_index']-1]
        gu1.cards[powerplay['card1_index']-1] = replace_card2
        gu2.cards[powerplay['card2_index']-1] = replace_card1
        gu1.save!
        gu2.save!
        render_200("swapped cards successfully") and return 
      elsif powerplay['event'] == VIEW_SELF
        gu1 = game.game_users.find_by_user_id(game.turn)
        view_card = gu1.cards[powerplay['view_card_index']-1]
        render_200(nil, {
          'card' => view_card
        }) and return
      else
        gu2 = game.game_users.find_by_user_id(powerplay['player_id'])
        view_card = gu2.cards[powerplay['view_card_index']-1]
        render_200(nil, {
          'card' => view_card
        }) and return
      end
      
    rescue StandardError => ex
      render_400(ex.message)
    end
  end

  private

  def filter_params
    params.permit(:game_id, :turn, :show, :player, event: {} , offload: {}, powerplay: {})
  end
end