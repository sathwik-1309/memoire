class GameController < ApplicationController
  before_action :set_current_user

  def index
    arr = []
    if @current_user.present?
      games = current_user.game_users.map{|gu| gu.game}.filter{|game| game.status == ONGOING}
    else
      games = Game.all
    end
    
    games.each do |game|
      arr << {
        "id" => game.id,
        "status" => game.status,
        # "inplay" => game.inplay,
        # "pile" => game.pile,
        # "used" => game.used,
      }
    end
    render(:json => arr)
  end

  def create
    players = User.where(id: [filter_params[:player1], filter_params[:player2], filter_params[:player3]])
    
    if players.length != 3
      render_400("Player/Players dont exist, game needs 3 players") and return
    end
    @game = Game.new
    @game.status = ONGOING
    @game.pile = Game.new_pile
    players = User.random_shuffle(players)
    @game.play_order = players.map{|player| player.id}
    @game.turn = @game.play_order[0]
    begin
      @game.save!
      @game.create_game_users(players)
      render_200("game created", {
        "id": @game.id,
        "players": players.map{|player| {'id'=> player.id, 'name'=>player.name} }
      })
    rescue StandardError => ex
      render_400(ex.message)
    end
  end

  def details
    @game = Game.find_by(id: params[:id])
    if @game.nil?
      render_400("Game not found") and return
    end
    begin
      render_200(nil, {
        "id": @game.id,
        "players": @game.game_users.map{|gu| {'id'=> gu.user_id, 'name'=>gu.user.name ,'cards'=> gu.cards} },
        "turn": @game.turn,
        "play_order": @game.play_order,
        "stage": @game.stage,
        "pile": @game.pile,
        "inplay": @game.inplay,
        "used": @game.used
      })
    rescue StandardError => ex
      render_400(ex.message)
    end
  end

  # def initial_view
  #   if @current_user.nil?
  #     render_400("User not authorized") and return
  #   end
  #   gu = @current_user.game_users.find_by_game_id(params[:id])
  #   if gu.nil?
  #     render_400("Game not found") and return
  #   end
  #   @game = gu.game
  #   begin
  #     if gu.initial_view
  #       render_400("alreday viewed") and return
  #     end
  #     gu.initial_view = true
  #     gu.save!
  #     render_200(nil,{
  #       'card_1' => gu.cards[0],
  #       'card_2' => gu.cards[1]
  #     })
  #   rescue StandardError => ex
  #     render_400(ex.message)
  #   end
  # end

  def online_games
    if @current_user.nil?
      render_400("Unauthorized") and return
    end
    begin
    games = @current_user.games.filter{|game| game.status == ONGOING}
    hash = games.map{|game| game.attributes }
    render_200(nil, hash)
    rescue StandardError => ex
      render_400(ex.message)
    end
  end

  def close_offloads
    game =  Game.find_by(id: params[:game_id])
    if game.nil?
      render_404("game not found") and return
    end
    begin
      offloads = game.current_play.offloads
      if offloads.present?
        game.turn = game.update_turn_to_next(offloads[-1]['player1_id'])
      else
        game.turn = game.update_turn_to_next(game.turn)
      end
      game.stage = CARD_DRAW
      game.save!
      render_200("game stage and turn updated successfully",{
        "stage" => game.stage,
        "turn" => game.turn
      })
    rescue StandardError => ex
      render_400(ex.message)
    end

  end

  def user_play
    # if @current_user.id == 
    if @current_user.nil?
      render_400("User not authorized") and return
    end
    gu = @current_user.game_users.find_by_game_id(params[:id])
    if gu.nil?
      render_400("Game not found") and return
    end

    game = gu.game
    render_400("Game is dead") and return if game.dead?

    hash = game.attributes.slice('stage', 'play_order', 'timeout')
    unless game.started?
      hash['game_user_status'] = gu.status
      render_200(nil, hash) and return
    end

    if game.finished?
      hash['show_called_by'] = game.meta['show_called_by']
      hash['show_cards'] = show_cards
    end

    hash['turn'] = User.find_by_id(game.turn).name
    hash['last_used'] = game.used[-1]
    if game.stage == CARD_DRAW
      if game.plays.length > 1
        play = game.plays[-2]
        hash['offloads'] = play.offloads
      end
    elsif game.stage == OFFLOADS
      powerplay = game.current_play.powerplay
      hash['powerplay'] = powerplay
    end
    table = []
    index = game.play_order.index(@current_user.id)
    total_players = game.play_order.length
    count = 0
    game_users = game.game_users
    while count < total_players
      gu = game_users.find{|gu1| gu1.user_id == game.play_order[(index+count)%total_players]}
      temp = {}
      temp['player_id'] = gu.user_id
      temp['name'] = gu.user.name
      if game.finished?
        temp['cards'] = gu.cards
        temp['finished_at'] = game.meta['game_users_sorted'].index(gu.user_id) + 1
      else
        temp['cards'] gu.cards.map{|card| card.present? ? 1 : 0}
      end
      count += 1
      table << temp
    end
    if game.turn == @current_user.id
      play = game.current_play
      hash['your_turn'] = true
      case game.stage 
      when DOR
        hash['card_drawn'] = play.card_draw['card_drawn']
      when POWERPLAY
        play = game.current_play
        hash['powerplay_type'] = play.powerplay_type
      end
    end
    hash['table'] = table
    render_200(nil, hash)
  end


  def start_ack
    if @current_user.nil?
      render_400("User not authorized") and return
    end
    gu = @current_user.game_users.find_by_game_id(params[:id])
    if gu.nil?
      render_400("Game not found") and return
    end

    gu.status = GAME_USER_WAITING_TO_JOIN
    game = gu.game
    gu.save!
    if game.check_start_ack
      game.stage = INITIAL_VIEW
      game.game_users.each do |gu|
        gu.status = GAME_USER_IS_PLAYING
        gu.save!
      end
      game.timeout = Time.now.utc + TIMEOUT_IV.seconds
      game.save!
      ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": INITIAL_VIEW, "id": 1})
      Thread.new do
        sleep(TIMEOUT_IV)
        game.stage = CARD_DRAW
        game.timeout = Time.now.utc + TIMEOUT_CD.seconds
        game.save!
        ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": CARD_DRAW, "turn": User.find_by_id(game.turn).authentication_token, "id": 2})
      end
    end
    render_200("Waiting for other players to join...")
  end

  def view_initial
    if @current_user.nil?
      render_400("User not authorized") and return
    end
    gu = @current_user.game_users.find_by_game_id(params[:id])
    if gu.nil?
      render_400("Game not found") and return
    end
    if gu.view_count >= 2
      render_400("Already viewed 2 cards") and return
    end

    gu.view_count += 1
    gu.save!
    render_200(nil,{
      "card" => gu.cards[filter_params[:card_index].to_i]
    })

  end

  private

  def filter_params
    params.permit(:player1, :player2, :player3, :player_id, :card_index)
  end

end