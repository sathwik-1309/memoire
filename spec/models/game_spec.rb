# frozen_string_literal: true

RSpec.describe Game, type: :model do
  it 'has a valid factory' do
    game = FactoryBot.create(:game)
    expect(game).to be_valid
  end

  context 'finish_game' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game, used: ['A ♥'], stage: CARD_DRAW, turn: @user.id)
      @game_user = create(:game_user, user: @user, game: @game, status: GAME_USER_IS_PLAYING, cards: ['A ♣', nil, '3 ♣', '2 ♣'])
      @game_bot1 = create(:game_bot, user: @bot1, game: @game, status: GAME_USER_IS_PLAYING, cards: ['K ♣', 'J ♣', '10 ♣', '8 ♣'])
      @game_bot2 = create(:game_bot, user: @bot2, game: @game, status: GAME_USER_IS_PLAYING, cards: ['2 ♣', '4 ♣', '9 ♣', '10 ♣'])
      @play = create(:play, game_id: @game.id, card_draw: {'card_drawn'=> '7 ♥'})
    end

    it 'should update correctly for showcards' do
      @game.finish_game('showcards', @user)
      expect(@game.reload.status).to eq(FINISHED)
      expect(@game.timeout).to eq(nil)
      expect(@game.meta['show_called_by']).to eq({"player_id"=>@user.id, "name"=>@user.name, "is_winner"=>true})
      expect(@game.meta['game_users_sorted']).to eq([@user.id, @bot2.id, @bot1.id])
      expect(@game.meta['finish_event']).to eq('showcards')
    end
  end
end
