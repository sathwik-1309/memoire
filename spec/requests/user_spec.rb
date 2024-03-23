# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserController, type: :controller do


  describe 'GET #index' do
    it 'returns a success response' do
      create(:user)
      get :index, params: {}
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_attributes) { attributes_for(:user) }

      it 'creates a new User' do
        expect do
          post :create, params: valid_attributes
        end.to change(User, :count).by(1)
      end

      it 'renders a JSON response with the new user' do
        post :create, params: valid_attributes
        expect(response).to have_http_status(:created)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        expect(response.body).to include('name')
      end
    end
  end
end
