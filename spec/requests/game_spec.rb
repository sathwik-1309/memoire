# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GameController, type: :controller do
  describe 'GET #index' do
    let(:user) { create(:user) }
    let(:game1) { create(:game, :ongoing) }
    let(:game2) { create(:game, :finished) }
    before do
      create(:game_user, user: user, game: game1)
      create(:game_user, user: user, game: game2)
    end
    context 'when there is no current user' do
      it 'returns all games' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['games'].size).to eq(Game.count)
      end
    end

    context 'when there is a current user' do
      it 'returns only the ongoing games of the current user' do
        get :index, params: { auth_token: user.authentication_token }
        expect(response).to have_http_status(:ok)
        games = JSON.parse(response.body)['games']
        expect(games.size).to eq(1)
        expect(games.first['id']).to eq(game1.id)
        expect(games.first['status']).to eq(ONGOING)
      end
    end
  end

  describe 'POST #multiplayer_create' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }
    let(:user4) { create(:user) }
    let(:user5) { create(:user) }
    context 'with 3-4 players' do
      it 'creates a new game' do
        post :multiplayer_create, params: { player_ids: [user1.id, user2.id, user3.id] }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['message']).to eq('game created')
      end

      it 'creates a new game with 4 players' do
        post :multiplayer_create, params: { player_ids: [user1.id, user2.id, user3.id, user4.id] }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['message']).to eq('game created')
      end
    end

    context 'with less than 3 players' do
      it 'returns a bad request status' do
        post :multiplayer_create, params: { player_ids: [user1.id, user2.id] }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Game allows 3-4 players only')
      end
    end

    context 'with more than 4 players' do
      it 'returns a bad request status' do
        post :multiplayer_create, params: { player_ids: [user1.id, user2.id, user3.id, user4.id, user5.id] }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Game allows 3-4 players only')
      end
    end
  end

  describe 'GET #details' do
    let(:game) { create(:game, :ongoing) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }
    before do
      create(:game_user, user: user1, game: game)
      create(:game_user, user: user2, game: game)
      create(:game_user, user: user3, game: game)
    end

    it 'returns game details when game is found' do
      get :details, params: { id: game.id }
      validate_response(response, 200)
      res = Oj.load(response.body)
      expect(res['id']).to eq(game.id)
      expect(res['players'].length).to eq(3)
      expect(res['turn']).to eq(game.turn)
      expect(res['play_order']).to eq(game.play_order)
      expect(res['stage']).to eq(game.stage)
      expect(res['pile']).to eq(game.pile)
      expect(res['inplay']).to eq(game.inplay)
      expect(res['used']).to eq(game.used)
      expect(res['status']).to eq(game.status)
    end
    it 'returns error when game is not found' do
      get :details, params: { id: -1 }
      validate_response(response, 404)
      res = Oj.load(response.body)
      expect(res['error']).to eq('Game not found')
    end
  end

  # describe 'GET #online_games' do
  #   let(:user1) { create(:user) }
  #   let(:user2) { create(:user) }
  #   let(:game1) { create(:game, :ongoing) }
  #   let(:game2) { create(:game, :finished) }
  #   before do
  #     create(:game_user, user: user1, game: game1)
  #     create(:game_user, user: user1, game: game2)
  #     create(:game_user, user: user2, game: game2)
  #   end
  #
  #   context 'when there is a current user' do
  #     it 'returns only ongoing games of current user' do
  #       get :online_games, params: { auth_token: user1.authentication_token }
  #       validate_response(response, 200)
  #       res = Oj.load(response.body)
  #       expect(res.length).to eq(1)
  #       expect(res[0]['id']).to eq(game1.id)
  #     end
  #
  #     it 'returns empty array if no ongoing games for current user' do
  #       get :online_games, params: { auth_token: user2.authentication_token }
  #       validate_response(response, 200)
  #       res = Oj.load(response.body)
  #       expect(res).to eq([])
  #     end
  #     it 'returns error if something goes wrong' do
  #       allow_any_instance_of(User).to receive(:games).and_raise(StandardError, 'Something went wrong')
  #       get :online_games, params: { auth_token: user2.authentication_token }
  #       validate_response(response, :bad_request)
  #       res = Oj.load(response.body)
  #       expect(res['error']).to eq('Something went wrong')
  #     end
  #   end
  #
  #   # context 'when there is no current user' do
  #   #   it 'returns a bad request status' do
  #   #     get :online_games
  #   #     validate_response(response, :bad_request)
  #   #     expect(Oj.load(response.body)['error']).to eq('User not authorized')
  #   #   end
  #   # end
  # end

  describe 'GET #view_initial' do
    let(:user) { create(:user) }
    let(:new_user) { create(:user) }
    let(:game) { create(:game, :ongoing) }
    before do
      @game_user = create(:game_user, user: user, game: game, cards: ['A ♣', '9 ♣', '3 ♣', '2 ♣'])
    end


    it "increments view count and returns card when view count is less than 2" do
      get :view_initial, params: { id: game.id, auth_token: user.authentication_token, card_index: 1 }
      validate_response(response, 200)
      res = Oj.load(response.body)
      expect(res['card']).to eq('9 ♣')
      expect(@game_user.reload.view_count).to eq(1)
    end

    it "returns error when view count is 2" do
      @game_user.update(view_count: 2)
      get :view_initial, params: { id: game.id, auth_token: user.authentication_token }
      validate_response(response, 400)
      res = Oj.load(response.body)
      expect(res['error']).to eq("Already viewed 2 cards")
    end

    it "returns error when game is not found" do
      get :view_initial, params: { id: game.id, auth_token: new_user.authentication_token }
      validate_response(response, 404)
      res = Oj.load(response.body)
      expect(res['error']).to eq("Game not found")
    end
  end

  describe 'POST #start_ack' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game)
      @game_user = create(:game_user, user: @user, game: @game)
      @game_bot1 = create(:game_bot, user: @bot1, game: @game)
      @game_bot2 = create(:game_bot, user: @bot2, game: @game)
    end

    it 'returns error if unauthorized' do
      post :start_ack, params: {id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
    end

    it 'returns error if game not found' do
      post :start_ack, params: {auth_token: @game_user.user.authentication_token, id: 1000}
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)['error']).to eq('Game not found')
    end

    it 'starts the game when last user triggers start-ack' do
      post :start_ack, params: {auth_token: @game_user.user.authentication_token, id: @game.id}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['message']).to eq('Waiting for other players to join...')
      expect(@game.reload.stage).to eq(INITIAL_VIEW)
      expect(@game.status).to eq(ONGOING)
      expect(@game.game_users.map{|gu| gu.status}).to eq(Array.new(3, GAME_USER_IS_PLAYING))
    end

    it 'starts the game when last user triggers start-ack' do
      user2 = create(:user)
      game2 = create(:game)
      game_user = create(:game_user, user: @user, game: game2)
      game_user2 = create(:game_user, user: user2, game: game2)
      game_bot = create(:game_bot, user: @bot2, game: game2)
      post :start_ack, params: {auth_token: game_user.user.authentication_token, id: game2.id}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['message']).to eq('Waiting for other players to join...')
      expect(game_user.reload.status).to eq(GAME_USER_WAITING)
      expect(game2.reload.status).to eq(NEW)
    end
  end

  describe 'GET #user_play' do
    before :each do
      @user1 = create(:user)
      @user2 = create(:user)
      @user3 = create(:user)
      @game = create(:game, stage: CARD_DRAW, turn: @user1.id, status: ONGOING, play_order: [@user1.id, @user2.id, @user3.id])
      @game_user1 = create(:game_user, user: @user1, game: @game)
      @game_user2 = create(:game_user, user: @user2, game: @game)
      @game_user3 = create(:game_user, user: @user3, game: @game)
    end

    it 'returns error if unauthorized' do
      get :user_play, params: {id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
    end

    it 'returns error if game not found' do
      get :user_play, params: {auth_token: @game_user1.user.authentication_token, id: 1000}
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)['error']).to eq('Game not found')
    end

    it 'should get user_play on card_draw on your turn' do
      get :user_play, params: {auth_token: @game_user1.user.authentication_token, id: @game.id}
      expect(response).to have_http_status(200)
      res = JSON.parse(response.body)
      expect(res['stage']).to eq(CARD_DRAW)
      expect(res['your_turn']).to eq(true)
    end
  end
end
