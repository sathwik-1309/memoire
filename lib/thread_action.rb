module ThreadAction

  def self.call_api(method, url, params={})
    begin
      case method
      when GET_API
        response = RestClient.get(url, params)
      when POST_API
        response = RestClient.post(url, params)
      when PUT_API
        response = RestClient.put(url, params)
      when DELETE_API
        response = RestClient.delete(url, params)
      else
        response = RestClient.get(url, params)
      end

      if [200,201].include? response.code
        return true, JSON.parse(response.body)
      else
        #TODO: logging
        puts "Error: Request failed"
        return false
      end
    rescue RestClient::ExceptionWithResponse => ex
      #TODO: logging
      puts "Error: Request failed with an  error response"
      return false
    rescue RestClient::Exception, StandardError => ex
      #TODO: logging
      # puts
      return false
    end
  end

  def self.bot_actions_initial_view(game)
    Thread.new do
      begin
        bot_users = game.bot_users
        bot_users.each do |bot_user|
        bot = bot_user.user
        Thread.new do
          begin
            indexes = [0,1,2,3].sample(2)
            url = "#{BACKEND_URL}/games/#{game.id}/view_initial"

            # view 1st card
            params = { auth_token: bot.authentication_token, card_index: indexes[0]}
            status, res = ThreadAction.call_api(GET_API, url, params)
            bot_user.update_self_seen(res['card'], indexes[0]) if status

            # view 2nd card
            params = { auth_token: bot.authentication_token, card_index: indexes[1]}
            status, res = ThreadAction.call_api(GET_API, url, params)
            bot_user.update_self_seen(res['card'], indexes[1]) if status
            bot_user.save!
          rescue StandardError => ex
            #TODO: logging
            puts  "Error: ThreadAction#bot_actions_initial_view: #{ex.message}"
          end
        end
      end
      rescue StandardError => ex
        #TODO: logging
        puts  "Error: ThreadAction#bot_actions_initial_view: #{ex.message}"
      end
    end

  end

  def self.bot_actions_card_draw(game)
    Thread.new do
      begin
      bot_user = game.bot_users.find_by(user_id: game.turn)
      return if bot_user.nil?
      url = "#{BACKEND_URL}/games/#{game.id}/card_draw"
      params = { auth_token: bot_user.user.authentication_token}
      status, res = ThreadAction.call_api(POST_API, url, params)
      rescue StandardError => ex
        #TODO: logging
        puts  "Error: ThreadAction#bot_actions_card_draw: #{ex.message}"
      end
    end
  end

  def self.bot_actions_discard(game, card_drawn)
    Thread.new do
      begin
        bot_user = game.bot_users.find_by(user_id: game.turn)
        return if bot_user.nil?
        return unless NORMAL_CARD_VALUES.include? Util.get_card_number(card_drawn)
        unknown_card_index = bot_user.get_self_unknown_index
        return unless unknown_card_index.present?
        url = "#{BACKEND_URL}/games/#{game.id}/discard_or_replace"
        params = { auth_token: bot_user.user.authentication_token, type: REPLACE, discarded_card_index: unknown_card_index}
        status, res = ThreadAction.call_api(PUT_API, url, params)
        if status
          bot_user.replace_self_card(card_drawn, unknown_card_index)
          bot_user.save!
        end

      rescue  StandardError => ex
        #TODO: logging
        puts  "Error: ThreadAction#bot_actions_discard: #{ex.message}"
      end
    end
  end

  def self.bot_actions_powerplay(game, powerplay_type)
    Thread.new do
      begin
        bot_user = game.bot_users.find_by(user_id: game.turn)
        return if bot_user.nil?
        case powerplay_type
        when VIEW_SELF
          unknown_indexes = bot_user.get_self_unknown_indexes
          return unless unknown_indexes.present?
          unknown_index = unknown_indexes.sample(1)
          url = "#{BACKEND_URL}/games/#{game.id}/powerplay"
          params = { auth_token: bot_user.user.authentication_token,
                     powerplay: {
                       'event' => VIEW_SELF,
                       'view_card_index' => unknown_index
                     }}
          status, res = ThreadAction.call_api(PUT_API, url, params)
          if status
            bot_user.update_self_seen(res['card'], unknown_index)
            bot_user.save!
          end
        when VIEW_OTHERS
          unknown_card, player_id = bot_user.get_others_unknown_card
          return unless unknown_card.present?
          url = "#{BACKEND_URL}/games/#{game.id}/powerplay"
          params = { auth_token: bot_user.user.authentication_token,
                     powerplay: {
                       'event' => VIEW_OTHERS,
                       'view_card_index' => unknown_card['index'],
                       'player_id' => player_id,
                     }}
          status, res = ThreadAction.call_api(PUT_API, url, params)
          if status
            bot_user.update_others_seen(res['card'], unknown_card['index'], player_id)
            bot_user.save!
          end
        when SWAP_CARDS

        else
          #nothing
        end
      rescue StandardError => ex
        #TODO: logging
        puts  "Error: ThreadAction#bot_actions_discard: #{ex.message}"
      end
    end
  end

  def self.move_to_card_draw(game)
    Thread.new do
      begin
        sleep(TIMEOUT_IV)
        game.stage = CARD_DRAW
        game.timeout = Time.now.utc + TIMEOUT_CD.seconds
        game.save!
        ActionCable.server.broadcast(game.channel, {"timeout": game.timeout, "stage": CARD_DRAW, "turn": User.find_by_id(game.turn).authentication_token, "message": "stage #{CARD_DRAW}"})
        ThreadAction.bot_actions_card_draw(game)
      rescue StandardError => ex
        #TODO: logging
      end
    end
  end

end
