# frozen_string_literal: true

FactoryBot.define do
  factory :game do
    trait :ongoing do
      status { 'ongoing' }
    end

    trait :finished do
      status { 'finished' }
    end
  end
end
