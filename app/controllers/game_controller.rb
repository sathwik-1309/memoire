class GameController < ApplicationController
  before_action :set_current_user
  before_action :check_current_user, except: [:index, :create, :multiplayer_create, :details]

  def index
    games = if @current_user.present?
              @current_user.game_users.map(&:game).filter { |game| game.status == ONGOING }
            else
              Game.all
            end

    games = games.map { |game| game.attributes.slice('id', 'status') }

    render json: { games: games }, status: :ok
  end

  def create
    players = User.where(id: filter_params[:player_ids])
    render json: { error: "Must send at least 1 valid user" }, status: :bad_request and return unless players.present?
    if players.length < 4
      bots = Util.pick_n_random_items(Bot.all, 4-players.length)
      players += bots
    end

    @game = Game.new
    @game.status = START_ACK
    @game.pile = Game.new_pile
    players = User.random_shuffle(players)
    @game.play_order = players.map{|player| player.id}
    @game.turn = @game.play_order[0]
    @game.save!
    @game.create_game_users(players)
    render_201("game created", {
      "id": @game.id,
      "players": players.map{|player| {'id'=> player.id, 'name'=>player.name} }
    })
  end

  def multiplayer_create
    players = User.where(id: filter_params[:player_ids]).shuffle
    if players.count.between?(3, 4)
      @game = Game.create!(status: ONGOING, pile: Game.new_pile, play_order: players.pluck(:id), turn: players.first.id)
      @game.create_game_users(players)
      render json: { message: "game created", game: { id: @game.id, players: players.map { |player| { id: player.id, name: player.name } } } }, status: :created
    else
      render json: { error: "Game allows 3-4 players only" }, status: :bad_request
    end
  rescue StandardError => ex
    render json: { error: ex.message }, status: :bad_request
  end

  def details
    @game = Game.find_by(id: params[:id])
    if @game.nil?
      render json: { error: "Game not found" }, status: :not_found
    else
      render json: {
        id: @game.id,
        players: @game.game_users.map do |gu|
          {
            id: gu.user_id,
            name: gu.user.name,
            cards: gu.cards
          }
        end,
        turn: @game.turn,
        play_order: @game.play_order,
        stage: @game.stage,
        pile: @game.pile,
        inplay: @game.inplay,
        used: @game.used,
        status: @game.status
      }, status: :ok
    end
    #TODO: This is returning 200
  rescue StandardError => ex
    render json: { error: ex.message }, status: :bad_request
  end

  # def online_games
  #   if @current_user.nil?
  #     render_400("Unauthorized") and return
  #   end
  #   begin
  #     games = @current_user.games.filter{|game| game.status == ONGOING}
  #     hash = games.map{|game| game.attributes }
  #     render_200(nil, hash)
  #   rescue StandardError => ex
  #     render_400(ex.message)
  #   end
  # end

  # def close_offloads
  #   game =  Game.find_by(id: params[:id])
  #   if game.nil?
  #     render_404("game not found") and return
  #   end
  #   begin
  #     offloads = game.current_play.offloads
  #     if offloads.present?
  #       game.turn = game.update_turn_to_next(offloads[-1]['player1_id'])
  #     else
  #       game.turn = game.update_turn_to_next(game.turn)
  #     end
  #     game.stage = CARD_DRAW
  #     game.save!
  #     render_200("game stage and turn updated successfully",{
  #       "stage" => game.stage,
  #       "turn" => game.turn
  #     })
  #   rescue StandardError => ex
  #     render_400(ex.message)
  #   end
  #
  # end

  def user_play
    gu = @current_user.game_users.find_by_game_id(params[:id])
    render json: { error: "Already quit from game" }, status: 400 and return if gu.status == DEAD
    if gu.nil?
      render json: { error: "Game not found" }, status: 400 and return
    end

    game = gu.game
    render json: { error: "Game is dead" }, status: 400 and return if game.dead?

    hash = game.attributes.slice('stage', 'play_order', 'timeout', 'status')
    unless game.started?
      hash['game_user_status'] = gu.status
      render json: hash, status: 200 and return
    end

    if game.finished?
      hash['show_called_by'] = game.meta['show_called_by']
    end

    hash['turn'] = User.find_by_id(game.turn).name
    hash['turn_id'] = game.turn
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
      temp['user_status'] = gu.status
      if gu.status != GAME_USER_QUIT
        if game.finished?
          temp['cards'] = gu.cards
          temp['finished_at'] = game.meta['game_users_sorted'].index(gu.user_id) + 1
          temp['points'] = gu.points
        else
          temp['cards'] = gu.cards.map{|card| card.present? ? 1 : 0}
        end
      end
      count += 1
      table << temp
    end
    hash['table'] = table
    render json: hash, status: 200 and return if game.stage == FINISHED

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
    render json: hash, status: 200
  end

  def start_ack
    gu = @current_user.game_users.find_by_game_id(params[:id])
    if gu.nil?
      render_400("Game not found") and return
    end

    gu.status = GAME_USER_WAITING
    game = gu.game
    gu.save!
    if game.check_start_ack
      game.stage = INITIAL_VIEW
      game.status = ONGOING
      game.counter += 1
      game.game_users.each do |gu|
        gu.status = GAME_USER_IS_PLAYING
        gu.save!
      end
      game.timeout = Time.now.utc + TIMEOUT_IV.seconds
      game.save!
      # puts "Block 1 game timeout: #{game.timeout}"
      # puts "Block 1 enqueued at time #{Time.now.utc + TIMEOUT_IV.seconds}"
      CriticalWorker.perform_in(TIMEOUT_IV.seconds, 'move_to_card_draw', {'game_id' => game.id})
      # puts "Block 1 after enque time #{Time.now.utc + TIMEOUT_IV.seconds}"
      ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": INITIAL_VIEW, "message": "game started"})
      MyWorker.perform_in(1.second, 'bot_actions_initial_view', {'game_id' => game.id})
    end
    render_200("Waiting for other players to join...")
  end

  def view_initial
    gu = @current_user.game_users.find_by(game_id: params[:id])
    return render json: { error: "Game not found" }, status: :not_found if gu.nil?
    return render json: { error: "Already viewed 2 cards" }, status: 400 if gu.view_count >= 2

    gu.increment!(:view_count)
    render json: { card: gu.cards[filter_params[:card_index].to_i] }, status: 200
  end

  def quit
    gu = @current_user.game_users.find_by_game_id(params[:id])
    return render json: { error: "Game not found" }, status: :not_found if gu.nil?
    gu.status = GAME_USER_QUIT
    gu.meta['quit_time'] = Time.now.utc
    gu.save!
    if gu.game.active_users.length == 1
      ActionCable.server.broadcast(gu.game.channel, {"message": "user quit", "id": 3})
    else
      gu.game.finish_game('quit')
      ActionCable.server.broadcast(gu.game.channel, {"message": "game finished", "id": 4})
    end
    render json: { message: "Quit Successfull" }, status: :ok
  end

  private
  def check_current_user
    if @current_user.nil?
      render json: { error: "User not authorized" }, status: 400 and return
    end
  end

  def filter_params
    params.permit(:player_id, :card_index, player_ids: [])
  end

end
