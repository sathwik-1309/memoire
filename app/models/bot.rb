class Bot < User
  default_scope -> { where(is_bot: true) }

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
      puts "Error: Request failed with an  error response #{ex.message}"
      return false
    rescue RestClient::Exception, StandardError => ex
      #TODO: logging
      puts "Error- Bot#call_api: #{ex.message}"
      return false
    end
  end

end