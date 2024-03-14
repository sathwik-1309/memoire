# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { 'Test User' }
    authentication_token { 'token' }
    username { 'testuser' }
    password { 'password' }
  end
end
