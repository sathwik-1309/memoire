# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GameController, type: :controller do
  let(:user) { create(:user) }
  let(:game1) { create(:game, :ongoing) }
  let(:game2) { create(:game, :finished) }

  before do
    create(:game_user, user: user, game: game1)
    create(:game_user, user: user, game: game2)
  end

  describe 'GET #index' do
    context 'when there is no current user' do
      it 'returns all games' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['games'].size).to eq(Game.count)
      end
    end

    context 'when there is a current user' do
      before { sign_in user }

      it 'returns only the ongoing games of the current user' do
        get :index
        expect(response).to have_http_status(:ok)
        games = JSON.parse(response.body)['games']
        expect(games.size).to eq(1)
        expect(games.first['id']).to eq(game1.id)
        expect(games.first['status']).to eq('ONGOING')
      end
    end
  end

  describe 'POST #create' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }
    let(:user4) { create(:user) }
    let(:user5) { create(:user) }
    context 'with 3-4 players' do
      it 'creates a new game' do
        post :create, params: { player_ids: [user1.id, user2.id, user3.id] }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['message']).to eq('game created')
      end

      it 'creates a new game with 4 players' do
        post :create, params: { player_ids: [user1.id, user2.id, user3.id, user4.id] }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['message']).to eq('game created')
      end
    end

    context 'with less than 3 players' do
      it 'returns a bad request status' do
        post :create, params: { player_ids: [user1.id, user2.id] }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Game allows 3-4 players only')
      end
    end

    context 'with more than 4 players' do
      it 'returns a bad request status' do
        post :create, params: { player_ids: [user1.id, user2.id, user3.id, user4.id, user5.id] }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Game allows 3-4 players only')
      end
    end

    context 'when an exception is raised' do
      before do
        allow(Game).to receive(:create!).and_raise(StandardError, 'Something went wrong')
      end
      it 'returns a bad request status with an error message' do
        post :create, params: { player_ids: [user1.id, user2.id, user3.id] }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Something went wrong')
      end
    end
  end


end
