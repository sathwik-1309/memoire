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

  context 'bot memory' do
    context 'bot_mem_update_discard' do
      it 'should update bot memory if card is seen/unknown' do
        @user = create(:user)
        @bot1 = create(:bot)
        @bot2 = create(:bot)
        @game = create(:game, stage: DOR, play_order: [@user.id, @bot1.id, @bot2.id])
        @game_user = create(:game_bot, user: @user, game: @game, cards: ['10 ♠', '9 ♣', 'K ♦', '2 ♥'])
        @game_bot1 = create(:game_bot, user: @bot1, game: @game, cards: ['3 ♣', 'Q ♦', '5 ♣', '8 ♦'])
        @game_bot2 = create(:game_bot, user: @bot2, game: @game, cards: ['A ♠', '6 ♦', 'J ♣', '7 ♠'])
        @memory = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => @game_user.layout_memory_init
        }
        # bot 2 has not seen the card
        @game_bot2.meta['memory'] = @memory
        @game_bot2.save!
        # bot 1 has seen the card
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        expect(@game_bot1.meta['memory']['cards']['other']['10']).to eq([{"player_id"=>@user.id, "index"=>0}])
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => true, 'value'=>'10 ♠', 'index'=>0 })
        expect(@game_bot2.meta['memory']['cards']['other']['10']).to eq([])
        expect(@game_bot2.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => false, 'index'=>0 })
        @game.bot_mem_update_discard(@user, 0)
        expect(@game_bot1.reload.meta['memory']['cards']['other']['10']).to eq([])
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => false, 'index'=>0 })
        expect(@game_bot2.reload.meta['memory']['cards']['other']['10']).to eq([])
        expect(@game_bot2.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => false, 'index'=>0 })
      end
    end

    context 'bot_mem_update_self_offload' do
      it 'should update bot memory if card is seen/unknown' do
        @user = create(:user)
        @bot1 = create(:bot)
        @bot2 = create(:bot)
        @game = create(:game, stage: DOR, play_order: [@user.id, @bot1.id, @bot2.id])
        @game_user = create(:game_bot, user: @user, game: @game, cards: ['10 ♠', '9 ♣', 'K ♦', '2 ♥'])
        @game_bot1 = create(:game_bot, user: @bot1, game: @game, cards: ['3 ♣', 'Q ♦', '5 ♣', '8 ♦'])
        @game_bot2 = create(:game_bot, user: @bot2, game: @game, cards: ['A ♠', '6 ♦', 'J ♣', '7 ♠'])
        @memory = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => @game_user.layout_memory_init
        }
        # bot 2 has not seen the card
        @game_bot2.meta['memory'] = @memory
        @game_bot2.save!
        # bot 1 has seen the card
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        expect(@game_bot1.meta['memory']['cards']['other']['10']).to eq([{"player_id"=>@user.id, "index"=>0}])
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => true, 'value'=>'10 ♠', 'index'=>0 })
        expect(@game_bot2.meta['memory']['cards']['other']['10']).to eq([])
        expect(@game_bot2.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => false, 'index'=>0 })
        @game.bot_mem_update_self_offload(@user, 0)
        expect(@game_bot1.reload.meta['memory']['cards']['other']['10']).to eq([])
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq(nil)
        expect(@game_bot2.reload.meta['memory']['cards']['other']['10']).to eq([])
        expect(@game_bot2.meta['memory']['layout'][0]['cards'][0]).to eq(nil)
      end
    end

    context 'bot_mem_update_cross_offload' do
      before :each do
        @user = create(:user)
        @bot1 = create(:bot)
        @bot2 = create(:bot)
        @game = create(:game, stage: DOR, play_order: [@user.id, @bot1.id, @bot2.id])
        @game_user = create(:game_bot, user: @user, game: @game, cards: ['10 ♠', '9 ♣', 'K ♦', '2 ♥'])
        @game_bot1 = create(:game_bot, user: @bot1, game: @game, cards: ['3 ♣', 'Q ♦', '5 ♣', '8 ♦'])
        @game_bot2 = create(:game_bot, user: @bot2, game: @game, cards: ['A ♠', '6 ♦', 'J ♣', '7 ♠'])
        @memory = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => @game_user.layout_memory_init
        }
        # bot 2 has not seen the cards
        @game_bot2.meta['memory'] = @memory
        @game_bot2.save!
      end
      it 'should update bot memory when both cards are known' do
        # bot 1 has seen the cards
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['cards']['other']['5'] << {'player_id' => @bot2.id, 'index' => 2 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @memory['layout'][2]['cards'][2] = {'seen' => true, 'value'=>'5 ♣', 'index'=>2 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        expect(@game_bot1.meta['memory']['cards']['other']['10']).to eq([{"player_id"=>@user.id, "index"=>0}])
        expect(@game_bot1.meta['memory']['cards']['other']['5']).to eq([{"player_id"=>@bot2.id, "index"=>2}])
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => true, 'value'=>'10 ♠', 'index'=>0 })
        expect(@game_bot1.meta['memory']['layout'][2]['cards'][2]).to eq({'seen' => true, 'value'=>'5 ♣', 'index'=>2 })
        expect(@game_bot2.meta['memory']['layout'][0]['cards'][0]).to eq({'seen' => false, 'index'=>0 })
        @game.bot_mem_update_cross_offload(@user, @bot2, 2, 0)
        expect(@game_bot1.reload.meta['memory']['cards']['other']['10']).to eq([{'player_id'=>@bot2.id, 'index'=>2}])
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq(nil)
        expect(@game_bot1.meta['memory']['cards']['other']['5']).to eq([])
        expect(@game_bot1.meta['memory']['layout'][2]['cards'][2]).to eq({'seen'=>true, 'value'=>'10 ♠', 'index'=>2})
        expect(@game_bot2.reload.meta['memory']['layout'][0]['cards'][0]).to eq(nil)
      end

      it 'should update bot memory' do
        # bot 1 has seen the offloaded card
        @memory['cards']['other']['5'] << {'player_id' => @bot2.id, 'index' => 2 }
        @memory['layout'][2]['cards'][2] = {'seen' => true, 'value'=>'5 ♣', 'index'=>2 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_cross_offload(@user, @bot2, 2, 0)
        expect(@game_bot1.reload.meta['memory']['cards']['other']['5']).to eq([])
        expect(@game_bot1.meta['memory']['layout'][2]['cards'][2]).to eq({'seen'=>false, 'index'=>2})
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq(nil)
      end

      it 'should update bot memory' do
        # bot 1 has seen the replaced card
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_cross_offload(@user, @bot2, 2, 0)
        expect(@game_bot1.reload.meta['memory']['cards']['other']['10']).to eq([{'player_id' => @bot2.id, 'index' => 2 }])
        expect(@game_bot1.meta['memory']['layout'][2]['cards'][2]).to eq({'seen'=>true, 'value'=>'10 ♠', 'index'=>2})
        expect(@game_bot1.meta['memory']['layout'][0]['cards'][0]).to eq(nil)
      end
    end
  end

end