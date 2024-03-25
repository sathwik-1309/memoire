class MyWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :default

  def perform(method_name, args={})
    if self.respond_to?(method_name)
      puts "found #{method_name}, args: #{args}"
      self.method(method_name).call(args)
    else
      puts "#{method_name} not found"
    end
  end

  def bot_actions_card_draw(args)
    game = Game.find_by_id(args['game_id'])
    game.bot_actions_card_draw
  end

  def bot_actions_initial_view(args)
    game = Game.find_by_id(args['game_id'])
    game.bot_actions_initial_view
  end

  def trigger_bot_initial_view(args)
    game_bot = GameBot.find_by_id(args['game_bot_id'])
    game_bot.trigger_initial_view(args['index'])
  end

  def bot_actions_discard(args)
    game = Game.find_by_id(args['game_id'])
    game.bot_actions_discard(args['card_drawn'])
  end

  def bot_actions_powerplay(args)
    game = Game.find_by_id(args['game_id'])
    game.bot_actions_powerplay(args['powerplay_type'])
  end

  def bot_actions_offload(args)
    game = Game.find_by_id(args['game_id'])
    game.bot_actions_offload
  end

  def trigger_bot_offloads(args)
    game_bot = GameBot.find_by_id(args['game_bot_id'])
    game_bot.trigger_offloads
  end

  def trigger_bot_self_offload(args)
    game_bot = GameBot.find_by_id(args['game_bot_id'])
    game_bot.trigger_self_offload(args['card_hash'])
  end

  def trigger_bot_cross_offload(args)
    game_bot = GameBot.find_by_id(args['game_bot_id'])
    game_bot.trigger_cross_offload(args['card_hash'])
  end

end
