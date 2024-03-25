class CriticalWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :critical

  def perform(method_name, args={})
    if self.respond_to?(method_name)
      self.method(method_name).call(args)
    else
      puts "#{method_name} not found"
    end
  end

  def card_draw_follow_up(args)
    game = Game.find_by_id(args['game_id'])
    game.card_draw_follow_up if game.status == ONGOING and game.counter == args['counter']
  end

  def dor_follow_up(args)
    game = Game.find_by_id(args['game_id'])
    game.dor_follow_up if game.status == ONGOING and game.counter == args['counter']
  end

  def powerplay_follow_up(args)
    game = Game.find_by_id(args['game_id'])
    game.powerplay_follow_up if game.status == ONGOING
  end

  def offloads_follow_up(args)
    game = Game.find_by_id(args['game_id'])
    game.offloads_follow_up if game.status == ONGOING
  end

  def finished_follow_up(args)
    game = Game.find_by_id(args['game_id'])
    game.finished_follow_up if game.status == ONGOING
  end

  def move_to_card_draw(args)
    game = Game.find_by_id(args['game_id'])
    game.move_to_card_draw
  end

end
