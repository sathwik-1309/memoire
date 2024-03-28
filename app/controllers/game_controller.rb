class GameController < ApplicationController
  before_action :set_current_user
  before_action :check_current_user, except: [:index, :create, :multiplayer_create, :details]
  before_action :check_game_user, only: [:user_play, :start_ack, :view_initial, :quit]

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
    players = User.random_shuffle(players)

    game = Game.create!(status: START_ACK,
                        pile: Game.new_pile,
                        play_order: players.map{|player| player.id},
                        turn: players.play_order[0])
    game.create_game_users(players)
    render json: {
      message: 'game created',
      id: game.id,
      players: players.map{|player| {'id'=> player.id, 'name'=>player.name}}
    }, status: 201
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
  end

  def details
    @game = Game.find_by_id(params[:id])
    render json: { error: 'Game not found' }, status: 404 and return if @game.nil?
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
    game = @game_user.game
    render json: { error: "Game is dead" }, status: 400 and return if game.dead?

    hash = game.attributes.slice('stage', 'play_order', 'timeout', 'status', 'turn')
    unless game.started?
      hash['game_user_status'] = @game_user.status
      render json: hash, status: 200 and return
    end

    hash['last_used'] = game.used[-1]
    hash['table'] = game.get_user_play_table(@current_user)

    if game.finished?
      hash['show_called_by'] = game.meta['show_called_by'] if game.meta['finish_event'] == 'showcards'
      hash['leaderboard'], hash['your_position'] = game.get_leaderboard_hash(@current_user)
      render json: hash, status: 200 and return
    end

    if game.turn == @current_user.id
      play = game.current_play
      hash['your_turn'] = true
      case game.stage
      when DOR
        hash['card_drawn'] = play.card_draw['card_drawn']
      when POWERPLAY
        hash['powerplay_type'] = play.powerplay_type
      else
        # eat 5 star and do nothing
      end
    end
    render json: hash, status: 200
  end

  def start_ack
    @game_user.status = GAME_USER_WAITING
    game = @game_user.game
    @game_user.save!
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
      # puts "Block 1 after enqueue time #{Time.now.utc + TIMEOUT_IV.seconds}"
      ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": INITIAL_VIEW, "message": "game started"})
      MyWorker.perform_in(1.second, 'bot_actions_initial_view', {'game_id' => game.id})
    end
    render json: {message: 'Waiting for other players to join...'}, status: 200
  end

  def view_initial
    return render json: { error: "Already viewed 2 cards" }, status: 400 if @game_user.view_count >= 2

    @game_user.increment!(:view_count)
    render json: { card: @game_user.cards[filter_params[:card_index].to_i] }, status: 200
  end

  def quit
    @game_user.status = GAME_USER_QUIT
    @game_user.meta['quit_time'] = Time.now.utc
    @game_user.save!
    if @game_user.game.active_users.length > 1
      ActionCable.server.broadcast(@game_user.game.channel, {"message": "user quit", "id": 3})
    else
      @game_user.game.finish_game('quit')
      ActionCable.server.broadcast(@game_user.game.channel, {"message": "game finished", "id": 4})
    end
    render json: { message: "Quit from game" }, status: :ok
  end

  private
  def check_current_user
    render json: { error: "Unauthorized" }, status: 400 if @current_user.nil?
  end

  def check_game_user
    @game_user = @current_user.game_users.find_by_game_id(params[:id])
    render json: { error: "Game not found" }, status: 404 and return if @game_user.nil?
    render json: { error: "Already quit from game" }, status: 400 if @game_user.status == DEAD
  end

  def filter_params
    params.permit(:player_id, :card_index, player_ids: [])
  end

end
