# frozen_string_literal: true

FactoryBot.define do
  factory :lobby do
    status {NEW}
    is_filled {false}
    players {[]}
  end
end