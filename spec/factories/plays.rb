# frozen_string_literal: true

FactoryBot.define do
  factory :play do
    turn { 1 }
    show { false }
    card_draw { {} }
    offloads { [] }
    powerplay { {} }
    association :game
  end
end
