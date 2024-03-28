# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayController, type: :controller do
  context  'POST #card_draw' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game, pile: Game.new_pile)
      @game_user = create(:game_user, user: @user, game: @game, status: GAME_USER_IS_PLAYING)
      @game_bot1 = create(:game_bot, user: @bot1, game: @game, status: GAME_USER_IS_PLAYING)
      @game_bot2 = create(:game_bot, user: @bot2, game: @game, status: GAME_USER_IS_PLAYING)
      @game.stage = CARD_DRAW
      @game.turn = @game_user.id
      @game.save!
    end

    it 'returns error if unauthorized' do
      post :card_draw, params: {game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
    end

    it 'returns error if game not found' do
      post :card_draw, params: {auth_token: @game_user.user.authentication_token, game_id: 1000}
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)['error']).to eq('Game not found')
    end

    it 'returns error if not your turn' do
      @game.turn = @game_bot1.id
      @game.save!
      post :card_draw, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Can only trigger on your turn')
    end

    it 'returns error when stage is not card_draw' do
      @game.stage = DOR
      @game.save!
      post :card_draw, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq("Can draw a card only in #{CARD_DRAW} stage")
    end

    it 'returns 200 with right params' do
      post :card_draw, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(200)
      res = JSON.parse(response.body)
      expect(res['card_drawn']).to_not eq(nil)
      expect(@game.reload.stage).to eq(DOR)
    end

  end

  context  'PUT #discard' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game, stage: DOR, turn: @user.id)
      @game_user = create(:game_user, user: @user, game: @game, status: GAME_USER_IS_PLAYING, cards: ['A ♣', 'Q ♣', '3 ♣', '2 ♣'])
      @game_bot1 = create(:game_bot, user: @bot1, game: @game, status: GAME_USER_IS_PLAYING)
      @game_bot2 = create(:game_bot, user: @bot2, game: @game, status: GAME_USER_IS_PLAYING)
      @play = create(:play, game_id: @game.id, card_draw: {'card_drawn' => '2 ♣'})
    end

    it 'returns error if unauthorized' do
      put :discard, params: {game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
    end

    it 'returns error if game not found' do
      put :discard, params: {auth_token: @game_user.user.authentication_token, game_id: 1000}
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)['error']).to eq('Game not found')
    end

    it 'returns error if not your turn' do
      @game.turn = @game_bot1.id
      @game.save!
      put :discard, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Can only trigger on your turn')
    end

    it 'returns error when stage is not discard' do
      @game.stage = OFFLOADS
      @game.save!
      put :discard, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Can discard only in discard stage')
    end

    it 'discard and moves to offload stage' do
      event = {'type' => DISCARD}
      put :discard, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, event: event}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['discarded_card']).to eq('2 ♣')
      expect(@play.reload.card_draw).to eq({"card_drawn"=>"2 ♣", "discarded_card"=>"2 ♣", "event"=>"discard"})
      expect(@game.reload.stage).to eq(OFFLOADS)
    end

    it 'discard and moves to powerplay stage' do
      @play.card_draw = {'card_drawn' => '8 ♣'}
      @play.save!
      event = {'type' => DISCARD}
      put :discard, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, event: event}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['discarded_card']).to eq('8 ♣')
      expect(@play.reload.card_draw).to eq({"card_drawn"=>"8 ♣", "discarded_card"=>"8 ♣", "event"=>"discard"})
      expect(@game.reload.stage).to eq(POWERPLAY)
    end

    it 'replace and moves to offload stage' do
      event = {'type' => REPLACE, 'discarded_card_index' => 1}
      put :discard, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, event: event}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['discarded_card']).to eq('Q ♣')
      expect(@game.reload.stage).to eq(OFFLOADS)
      expect(@play.reload.card_draw).to eq({"card_drawn"=>"2 ♣", "discarded_card"=>"Q ♣", "replaced_card"=>"2 ♣", "event"=>"replace"})
    end

  end

  context  'PUT #offload' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game, used: ['A ♥'], stage: OFFLOADS, turn: @bot2.id)
      @game_user = create(:game_user, user: @user, game: @game, status: GAME_USER_IS_PLAYING, cards: ['A ♣', 'Q ♣', '3 ♣', '2 ♣'])
      @game_bot1 = create(:game_bot, user: @bot1, game: @game, status: GAME_USER_IS_PLAYING)
      @game_bot2 = create(:game_bot, user: @bot2, game: @game, status: GAME_USER_IS_PLAYING)
      @play = create(:play, game_id: @game.id)
    end

    it 'returns error if unauthorized' do
      put :offload, params: {game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
    end

    it 'returns error if game not found' do
      put :offload, params: {auth_token: @game_user.user.authentication_token, game_id: 1000}
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)['error']).to eq('Game not found')
    end

    it 'returns error when stage is not discard' do
      @game.stage = POWERPLAY
      @game.save!
      put :offload, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Can offload only in offloads stage')
    end

    it 'self offload successfully with right params' do
      offload = {
        'type' => SELF_OFFLOAD,
        'offloaded_card_index' => 0,
      }
      put :offload, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, offload: offload}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['is_correct']).to eq(true)
      expect(@game.reload.stage).to eq(OFFLOADS)
      expect(@game.used[-1]).to eq('A ♣')
      expect(@game_user.reload.cards).to eq([nil, 'Q ♣', '3 ♣', '2 ♣'])
    end

    it 'wrong self offload' do
      offload = {
        'type' => SELF_OFFLOAD,
        'offloaded_card_index' => 1,
      }
      put :offload, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, offload: offload}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['is_correct']).to eq(false)
      expect(@game.reload.stage).to eq(OFFLOADS)
      expect(@game.used[-1]).to eq('A ♥')
      expect(@game_user.reload.cards.length).to eq(5)
    end

    it 'cross offload successfully with right params' do
      @game_bot1.cards = ['4 ♣', '6 ♣', '8 ♣', 'A ♦']
      @game_bot1.save!
      offload = {
        'type' => CROSS_OFFLOAD,
        'offloaded_card_index' => 3,
        'replaced_card_index' => 1,
        'player2_id' => @game_bot1.id
      }
      put :offload, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, offload: offload}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['is_correct']).to eq(true)
      expect(@game.reload.stage).to eq(OFFLOADS)
      expect(@game.used[-1]).to eq('A ♦')
      expect(@game_user.reload.cards).to eq(['A ♣', nil, '3 ♣', '2 ♣'])
      expect(@game_bot1.reload.cards).to eq(["4 ♣", "6 ♣", "8 ♣", "Q ♣"])
    end

    it 'wrong cross offload' do
      @game_bot1.cards = ['4 ♣', '6 ♣', '8 ♣', 'A ♦']
      @game_bot1.save!
      offload = {
        'type' => CROSS_OFFLOAD,
        'offloaded_card_index' => 2,
        'replaced_card_index' => 1,
        'player2_id' => @game_bot1.id
      }
      put :offload, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, offload: offload}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['is_correct']).to eq(false)
      expect(@game.reload.stage).to eq(OFFLOADS)
      expect(@game.used[-1]).to eq('A ♥')
      expect(@game_user.reload.cards.length).to eq(5)
      expect(@game_bot1.reload.cards).to eq(['4 ♣', '6 ♣', '8 ♣', 'A ♦'])
    end

  end

  context  'PUT #powerplay' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game, used: ['A ♥'], stage: POWERPLAY, turn: @user.id)
      @game_user = create(:game_user, user: @user, game: @game, status: GAME_USER_IS_PLAYING, cards: ['A ♣', 'Q ♣', '3 ♣', '2 ♣'])
      @game_bot1 = create(:game_bot, user: @bot1, game: @game, status: GAME_USER_IS_PLAYING, cards: ['2 ♣', '4 ♣', '9 ♣', '10 ♣'])
      @game_bot2 = create(:game_bot, user: @bot2, game: @game, status: GAME_USER_IS_PLAYING)
      @play = create(:play, game_id: @game.id, card_draw: {'card_drawn'=> '7 ♥'})
    end

    it 'returns error if unauthorized' do
      put :powerplay, params: {game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
    end

    it 'returns error if game not found' do
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: 1000}
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)['error']).to eq('Game not found')
    end

    it 'returns error if not your turn' do
      @game.turn = @bot1.id
      @game.save!
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Can only trigger on your turn')
    end

    it 'returns error when stage is not discard' do
      @game.stage = CARD_DRAW
      @game.save!
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Can access powerplay only in powerplay stage')
    end

    it 'returns error if powerplay type is different' do
      powerplay = {
        'event' => VIEW_OTHERS,
        'view_card_index' => 1,
      }
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, powerplay: powerplay}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Powerplay type not same')
    end

    it 'view_self powerplay' do
      powerplay = {
        'event' => VIEW_SELF,
        'view_card_index' => 1,
      }
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, powerplay: powerplay}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['card']).to_not eq(nil)
    end

    it 'return error when powerplay already used' do
      powerplay = {
        'event' => VIEW_SELF,
        'view_card_index' => 1,
      }
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, powerplay: powerplay}
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, powerplay: powerplay}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Powerplay already used for this play')
    end

    it 'view_others powerplay' do
      @play.card_draw = {'card_drawn' => '10 ♣'}
      @play.save!
      powerplay = {
        'event' => VIEW_OTHERS,
        'view_card_index' => 0,
        'player_id' => @bot1.id
      }
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, powerplay: powerplay}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['card']).to eq('2 ♣')
    end

    it 'swap_cards powerplay' do
      @play.card_draw = {'card_drawn' => 'J ♣'}
      @play.save!
      powerplay = {
        'event' => SWAP_CARDS,
        'player1_id' => @user.id,
        'player2_id' => @bot1.id,
        'card1_index' => 1,
        'card2_index' => 2,
      }
      put :powerplay, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id, powerplay: powerplay}
      expect(response).to have_http_status(200)
      expect(@game_user.reload.cards).to eq(['A ♣', '9 ♣', '3 ♣', '2 ♣'])
      expect(@game_bot1.reload.cards).to eq(['2 ♣', '4 ♣', 'Q ♣', '10 ♣'])
    end
  end

  context  'PUT #showcards' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game, used: ['A ♥'], stage: CARD_DRAW, turn: @user.id)
      @game_user = create(:game_user, user: @user, game: @game, status: GAME_USER_IS_PLAYING, cards: ['A ♣', 'Q ♣', '3 ♣', '2 ♣'])
      @game_bot1 = create(:game_bot, user: @bot1, game: @game, status: GAME_USER_IS_PLAYING, cards: ['2 ♣', '4 ♣', '9 ♣', '10 ♣'])
      @game_bot2 = create(:game_bot, user: @bot2, game: @game, status: GAME_USER_IS_PLAYING, cards: ['K ♣', 'J ♣', '10 ♣', '8 ♣'])
      @play = create(:play, game_id: @game.id, card_draw: {'card_drawn'=> '7 ♥'})
    end

    it 'returns error if unauthorized' do
      put :showcards, params: {game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
    end

    it 'returns error if game not found' do
      put :showcards, params: {auth_token: @game_user.user.authentication_token, game_id: 1000}
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)['error']).to eq('Game not found')
    end

    it 'returns error if not your turn' do
      @game.turn = @bot1.id
      @game.save!
      put :showcards, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Can only trigger on your turn')
    end

    it 'returns error when stage is not card_draw' do
      @game.stage = DOR
      @game.save!
      put :showcards, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Cannot Show after drawing card')
    end

    it 'returns error when you have 4 or more cards' do
      put :showcards, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)['error']).to eq('Cannot call show when you have 4 or more cards')
    end

    it 'returns error when you have 4 or more cards' do
      @game_user.cards = ['A ♣', nil, '3 ♣', '2 ♣']
      @game_user.save!
      put :showcards, params: {auth_token: @game_user.user.authentication_token, game_id: @game.id}
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['message']).to eq('Game is in finished state')
    end
  end
end
