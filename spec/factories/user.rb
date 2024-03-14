# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Test User #{n}" }
    authentication_token { 'token' }
    sequence(:username) { |n| "Test User #{n}" }
    password { 'password' }
  end
end
