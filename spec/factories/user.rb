# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    username { Faker::Internet.username }
    authentication_token { Faker::Internet.uuid }
    password { Faker::Internet.password }
  end
end
