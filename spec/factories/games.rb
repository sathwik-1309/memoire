# frozen_string_literal: true

FactoryBot.define do
  factory :game do
    trait :ongoing do
      status { ONGOING }
    end

    trait :finished do
      status { FINISHED }
    end
  end
end
