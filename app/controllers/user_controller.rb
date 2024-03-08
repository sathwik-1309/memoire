class UserController < ApplicationController

  def index
    arr = []
    users = User.all
    users.each do |user|
      arr << {
        "name" => user.name,
        "username" => user.username,
        "id" => user.id
      }
    end
    render(:json => arr)
  end

  def create
    attributes = filter_params.slice(:name, :username)

    attributes[:authentication_token] = Util.generate_random_string(10)
    @user = User.new(attributes)
    begin
      @user.save!
      render_200("User created", {
        "name": @user.name,
        "username": @user.username,
        "auth_token": @user.authentication_token
      })
    rescue StandardError => ex
      render_500(ex.message)
    end
  end

  private

  def filter_params
    params.permit(:name, :username)
  end

end