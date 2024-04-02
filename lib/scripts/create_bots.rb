module Scripts
  class CreateBots
    def self.create_initial_bots
      i = 1
      while i <= 10
        bot = Bot.new
        bot.name = "bot #{i}"
        bot.username = "bot_#{i}"
        bot.password = "bot_password"
        bot.authentication_token = Util.generate_random_string(10)
        bot.save!
        puts "Created bot ##{i}"
        i+=1
      end
    end
  end

end

Scripts::CreateBots.create_initial_bots
