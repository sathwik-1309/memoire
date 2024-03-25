# frozen_string_literal: true

FactoryBot.define do
  factory :bot do
    name { "bot #{Faker::Name.name}" }
    username { Faker::Internet.username }
    authentication_token { Faker::Internet.uuid }
    password { Faker::Internet.password }
  end
end
