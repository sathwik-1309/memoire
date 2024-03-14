# frozen_string_literal: true

FactoryBot.define do
  factory :game_user do
    association :user
    association :game
  end
end
