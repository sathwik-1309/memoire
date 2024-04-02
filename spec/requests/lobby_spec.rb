# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LobbyController, type: :controller do
  describe 'POST #join' do
    before :each do
      @user = create(:user)
    end

    it 'should join create new lobby and add a player' do
      @lobby = create(:lobby)
      post :join, params: {auth_token: @user.authentication_token}
      expect(response).to have_http_status(201)
      res = JSON.parse(response.body)
      expect(res['lobby']['status']).to eq(NEW)
      expect(res['lobby']['players'].length).to eq(1)
      expect(res['lobby']['is_filled']).to eq(false)
      expect(res['lobby']['game_id']).to eq(nil)
    end

    it 'should join existing lobby and add a player' do
      @lobby = create(:lobby)
      @user2 = create(:user)
      post :join, params: {auth_token: @user.authentication_token}
      expect(response).to have_http_status(201)
      res = JSON.parse(response.body)
      expect(res['lobby']['status']).to eq(NEW)
      expect(res['lobby']['players'].length).to eq(1)
      post :join, params: {auth_token: @user2.authentication_token}
      expect(response).to have_http_status(201)
      res = JSON.parse(response.body)
      expect(res['lobby']['status']).to eq(NEW)
      expect(res['lobby']['players'].length).to eq(2)
      expect(res['lobby']['is_filled']).to eq(false)
      expect(res['lobby']['game_id']).to eq(nil)
    end

    it 'should join existing lobby and follow up' do
      @lobby = create(:lobby)
      @user2 = create(:user)
      @user3 = create(:user)
      @user4 = create(:user)
      post :join, params: {auth_token: @user.authentication_token}
      expect(response).to have_http_status(201)
      post :join, params: {auth_token: @user2.authentication_token}
      expect(response).to have_http_status(201)
      post :join, params: {auth_token: @user3.authentication_token}
      expect(response).to have_http_status(201)
      post :join, params: {auth_token: @user4.authentication_token}
      expect(response).to have_http_status(201)
      res = JSON.parse(response.body)
      expect(res['lobby']['status']).to eq(FINISHED)
      expect(res['lobby']['players'].length).to eq(4)
      expect(res['lobby']['is_filled']).to eq(true)
      expect(res['lobby']['game_id']).to_not eq(nil)
    end

    it 'should join lobby and after 4 others have joined' do
      @lobby = create(:lobby)
      @user2 = create(:user)
      @user3 = create(:user)
      @user4 = create(:user)
      @user5 = create(:user)
      post :join, params: {auth_token: @user.authentication_token}
      expect(response).to have_http_status(201)
      post :join, params: {auth_token: @user2.authentication_token}
      expect(response).to have_http_status(201)
      post :join, params: {auth_token: @user3.authentication_token}
      expect(response).to have_http_status(201)
      post :join, params: {auth_token: @user4.authentication_token}
      expect(response).to have_http_status(201)
      post :join, params: {auth_token: @user5.authentication_token}
      expect(response).to have_http_status(201)
      res = JSON.parse(response.body)
      expect(res['lobby']['status']).to eq(NEW)
      expect(res['lobby']['players'].length).to eq(1)
      expect(res['lobby']['is_filled']).to eq(false)
      expect(res['lobby']['game_id']).to eq(nil)
    end
  end
end