# frozen_string_literal: true

class UserController < ApplicationController
  before_action :set_user, only: [:create]

  def index
    users = User.select(:id, :name, :username, :authentication_token)
    render json: users
  end

  def create
    if @user.save
      render json: @user.slice(:name, :username, :authentication_token), status: :created
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.new(user_params)
    @user.authentication_token = Util.generate_random_string(10)
  end

  def user_params
    params.permit(:name, :username)
  end
end
