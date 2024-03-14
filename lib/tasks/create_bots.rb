namespace :bots do
  desc "Print a custom message"
  task :initial_create do
    i = 0
    while i < 10
      bot = User.new
      bot.name = "bot #{i}"
      bot.username = "bot_#{i}"
      bot.is_bot = true
      bot.save!
    end
  end
end
