# frozen_string_literal: true

RSpec.describe Game, type: :model do
  it 'has a valid factory' do
    game = FactoryBot.create(:game)
    expect(game).to be_valid
  end
end
