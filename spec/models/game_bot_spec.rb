RSpec.describe GameUser, type: :model do
  it 'has a valid factory' do
    game_user = FactoryBot.create(:game_bot)
    expect(game_user).to be_valid
  end

  it 'has the correct associations' do
    game_user = FactoryBot.create(:game_bot)
    expect(game_user.user).to be_a(User)
    expect(game_user.game).to be_a(Game)
  end

  context 'bot actions#check_for_show' do
    before :each do
      @user = create(:user)
      @bot1 = create(:bot)
      @bot2 = create(:bot)
      @game = create(:game)
      @game_user = create(:game_bot, user: @user, game: @game)
      @game_bot1 = create(:game_bot, user: @bot1, game: @game)
      @game_bot2 = create(:game_bot, user: @bot2, game: @game)
    end
    it 'should be false if self cards is more than 4' do
      @game_bot1.meta = {
        'memory' => {
          'layout' => [
            { 'player_id' => @game_user.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
            { 'player_id' => @game_bot1.id , 'cards' => [{'seen'=>true, 'index'=>0, 'value'=>'2 ♥'}, {'seen'=>true, 'index'=>1, 'value'=>'6 ♥'}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
            { 'player_id' => @game_bot2.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
          ]
        }
      }
      expect(@game_bot1.check_for_show).to eq false
    end

    it 'should be false if all of self cards is not seen even with least cards' do
      @game_bot1.meta = {
        'memory' => {
          'layout' => [
            { 'player_id' => @game_user.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
            { 'player_id' => @game_bot1.id , 'cards' => [{'seen'=>true, 'index'=>0, 'value'=>'2 ♥'}, {'seen'=>true, 'index'=>1, 'value'=>'6 ♥'}, {'seen'=>false, 'index'=>2}, nil]},
            { 'player_id' => @game_bot2.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
          ]
        }
      }
      expect(@game_bot1.check_for_show).to eq false
    end

    it 'should be false if even one self card is a powerplay card even with least cards' do
      @game_bot1.meta = {
        'memory' => {
          'layout' => [
            { 'player_id' => @game_user.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
            { 'player_id' => @game_bot1.id , 'cards' => [{'seen'=>true, 'index'=>0, 'value'=>'2 ♥'}, {'seen'=>true, 'index'=>1, 'value'=>'K ♥'}, nil, nil]},
            { 'player_id' => @game_bot2.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
          ]
        }
      }
      expect(@game_bot1.check_for_show).to eq false
    end

    it 'should be true if all conditions satisfy' do
      @game_bot1.meta = {
        'memory' => {
          'layout' => [
            { 'player_id' => @game_user.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
            { 'player_id' => @game_bot1.id , 'cards' => [{'seen'=>true, 'index'=>0, 'value'=>'2 ♥'}, {'seen'=>true, 'index'=>1, 'value'=>'6 ♥'}, {'seen'=>true, 'index'=>1, 'value'=>'4 ♥'}, nil]},
            { 'player_id' => @game_bot2.id , 'cards' => [{'seen'=>false, 'index'=>0}, {'seen'=>false, 'index'=>1}, {'seen'=>false, 'index'=>2}, {'seen'=>false, 'index'=>3}]},
          ]
        }
      }
      expect(@game_bot1.check_for_show).to eq true
    end
  end
end