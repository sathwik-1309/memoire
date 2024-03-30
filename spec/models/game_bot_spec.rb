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
      @game_user = create(:game_user, user: @user, game: @game)
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
        @game_user = create(:game_user, user: @user, game: @game, cards: ['10 ♠', '9 ♣', 'K ♦', '2 ♥'])
        @game_bot1 = create(:game_bot, user: @bot1, game: @game, cards: ['3 ♣', 'Q ♦', '5 ♣', '8 ♦'])
        @game_bot2 = create(:game_bot, user: @bot2, game: @game, cards: ['A ♠', '6 ♦', 'J ♣', '7 ♠'])
        @memory = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => @game.layout_memory_init
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
        @game_user = create(:game_user, user: @user, game: @game, cards: ['10 ♠', '9 ♣', 'K ♦', '2 ♥'])
        @game_bot1 = create(:game_bot, user: @bot1, game: @game, cards: ['3 ♣', 'Q ♦', '5 ♣', '8 ♦'])
        @game_bot2 = create(:game_bot, user: @bot2, game: @game, cards: ['A ♠', '6 ♦', 'J ♣', '7 ♠'])
        @memory = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => @game.layout_memory_init
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
        @game_user = create(:game_user, user: @user, game: @game, cards: ['10 ♠', '9 ♣', 'K ♦', '2 ♥'])
        @game_bot1 = create(:game_bot, user: @bot1, game: @game, cards: ['3 ♣', 'Q ♦', '5 ♣', '8 ♦'])
        @game_bot2 = create(:game_bot, user: @bot2, game: @game, cards: ['A ♠', '6 ♦', 'J ♣', '7 ♠'])
        @memory = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => @game.layout_memory_init
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

    context 'bot_mem_update_swap_cards' do
      before :each do
        @user = create(:user)
        @bot1 = create(:bot)
        @bot2 = create(:bot)
        @game = create(:game, stage: DOR, play_order: [@user.id, @bot1.id, @bot2.id])
        @game_user = create(:game_user, user: @user, game: @game, cards: ['10 ♠', '9 ♣', 'K ♦', '2 ♥'])
        @game_bot1 = create(:game_bot, user: @bot1, game: @game, cards: ['A ♠', '6 ♦', 'J ♣', '7 ♠'])
        @game_bot2 = create(:game_bot, user: @bot2, game: @game, cards: ['3 ♣', 'Q ♦', '5 ♣', '8 ♦'])
        @memory = {
          'cards' => {
            'self' => Util.card_memory_init,
            'other' => Util.card_memory_init,
          },
          'layout' => @game.layout_memory_init
        }
        # bot 2 has not seen the cards
        @game_bot2.meta['memory'] = @memory
        @game_bot2.save!
      end
      it 'should update when other player knows both cards' do
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['cards']['other']['5'] << {'player_id' => @bot2.id, 'index' => 2 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @memory['layout'][2]['cards'][2] = {'seen' => true, 'value'=>'5 ♣', 'index'=>2 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot2, 0, 2)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['10']).to eq([{'index'=>2, 'player_id'=>@bot2.id}])
        expect(memory['cards']['other']['5']).to eq([{'index'=>0, 'player_id'=>@user.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> true, 'value'=>'5 ♣', 'index'=>0})
        expect(memory['layout'][2]['cards'][2]).to eq({'seen'=> true, 'value'=>'10 ♠', 'index'=>2})
      end

      it 'should update when other player knows one of the cards' do
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot2, 0, 2)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['10']).to eq([{'index'=>2, 'player_id'=>@bot2.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][2]['cards'][2]).to eq({'seen'=> true, 'value'=>'10 ♠', 'index'=>2})
      end

      it 'should update when other player knows one of the cards (2)' do
        @memory['cards']['other']['5'] << {'player_id' => @bot2.id, 'index' => 2 }
        @memory['layout'][2]['cards'][2] = {'seen' => true, 'value'=>'5 ♣', 'index'=>2 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot2, 0, 2)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['5']).to eq([{'index'=>0, 'player_id'=>@user.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> true, 'value'=>'5 ♣', 'index'=>0})
        expect(memory['layout'][2]['cards'][2]).to eq({'seen'=> false, 'index'=>2})
      end

      it 'should update when other player knows none of the cards' do
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot2, 0, 2)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][2]['cards'][2]).to eq({'seen'=> false, 'index'=>2})
      end

      it 'should update when involved player knows both of the cards' do
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @memory['cards']['self']['6'] << {'index' => 1}
        @memory['layout'][1]['cards'][1] = {'seen' => true, 'value'=>'6 ♦', 'index'=>1 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot1, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['10']).to eq([])
        expect(memory['cards']['self']['10']).to eq([{'index'=>1}])
        expect(memory['cards']['self']['6']).to eq([])
        expect(memory['cards']['other']['6']).to eq([{'index'=>0, 'player_id'=>@user.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> true, 'value'=>'6 ♦', 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen'=> true, 'value'=>'10 ♠', 'index'=>1})
      end

      it 'should update when involved player knows one of the cards' do
        @memory['cards']['self']['6'] << {'index' => 1}
        @memory['layout'][1]['cards'][1] = {'seen' => true, 'value'=>'6 ♦', 'index'=>1 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot1, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['self']['6']).to eq([])
        expect(memory['cards']['other']['6']).to eq([{'index'=>0, 'player_id'=>@user.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> true, 'value'=>'6 ♦', 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen'=> false, 'index'=>1})
      end

      it 'should update when involved player knows one of the cards(2)' do
        @memory['cards']['self']['6'] << {'index' => 1}
        @memory['layout'][1]['cards'][1] = {'seen' => true, 'value'=>'6 ♦', 'index'=>1 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@bot1, @user, 1, 0)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['self']['6']).to eq([])
        expect(memory['cards']['other']['6']).to eq([{'index'=>0, 'player_id'=>@user.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> true, 'value'=>'6 ♦', 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen'=> false, 'index'=>1})
      end

      it 'should update when involved player knows one of the cards (3)' do
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot1, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['10']).to eq([])
        expect(memory['cards']['self']['10']).to eq([{'index'=>1}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen' => true, 'value'=>'10 ♠', 'index'=>1 })
      end

      it 'should update when involved player knows one of the cards (4)' do
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@bot1, @user, 1, 0)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['10']).to eq([])
        expect(memory['cards']['self']['10']).to eq([{'index'=>1}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen' => true, 'value'=>'10 ♠', 'index'=>1 })
      end

      it 'should update when involved player knows none of the cards' do
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @bot1, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen'=> false, 'index'=>1})
      end

      it 'should update when player knows both of the cards of same user (other)' do
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @memory['cards']['other']['6'] << {'player_id' => @user.id, 'index' => 1}
        @memory['layout'][0]['cards'][1] = {'seen' => true, 'value'=>'6 ♦', 'index'=>1 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @user, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['10']).to eq([{'index'=>1, 'player_id'=>@user.id}])
        expect(memory['cards']['other']['6']).to eq([{'index'=>0, 'player_id'=>@user.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> true, 'value'=>'6 ♦', 'index'=>0})
        expect(memory['layout'][0]['cards'][1]).to eq({'seen'=> true, 'value'=>'10 ♠', 'index'=>1})
      end

      it 'should update when player knows one of the cards of same user (other)' do
        @memory['cards']['other']['10'] << {'player_id' => @user.id, 'index' => 0 }
        @memory['layout'][0]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @user, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['other']['10']).to eq([{'index'=>1, 'player_id'=>@user.id}])
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][0]['cards'][1]).to eq({'seen'=> true, 'value'=>'10 ♠', 'index'=>1})
      end

      it 'should update when player knows none of the cards of same user (other)' do
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@user, @user, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['layout'][0]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][0]['cards'][1]).to eq({'seen'=> false, 'index'=>1})
      end

      it 'should update when player knows both of the cards of same user (self)' do
        @memory['cards']['self']['10'] << {'index' => 0 }
        @memory['layout'][1]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @memory['cards']['self']['6'] << {'index' => 1}
        @memory['layout'][1]['cards'][1] = {'seen' => true, 'value'=>'6 ♦', 'index'=>1 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@bot1, @bot1, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['self']['10']).to eq([{'index'=>1}])
        expect(memory['cards']['self']['6']).to eq([{'index'=>0}])
        expect(memory['layout'][1]['cards'][0]).to eq({'seen'=> true, 'value'=>'6 ♦', 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen'=> true, 'value'=>'10 ♠', 'index'=>1})
      end

      it 'should update when player knows one of the cards of same user (self)' do
        @memory['cards']['self']['10'] << {'index' => 0 }
        @memory['layout'][1]['cards'][0] = {'seen' => true, 'value'=>'10 ♠', 'index'=>0 }
        @game_bot1.meta['memory'] = @memory
        @game_bot1.save!
        @game.bot_mem_update_swap_cards(@bot1, @bot1, 0, 1)
        memory = @game_bot1.reload.meta['memory']
        expect(memory['cards']['self']['10']).to eq([{'index'=>1}])
        expect(memory['layout'][1]['cards'][0]).to eq({'seen'=> false, 'index'=>0})
        expect(memory['layout'][1]['cards'][1]).to eq({'seen'=> true, 'value'=>'10 ♠', 'index'=>1})
      end

    end
  end

end