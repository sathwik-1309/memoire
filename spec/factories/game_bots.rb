# frozen_string_literal: true

FactoryBot.define do
  factory :game_bot do
    association :user
    association :game
  end
end
