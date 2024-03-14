# frozen_string_literal: true

RSpec.describe GameUser, type: :model do
  it 'has a valid factory' do
    game_user = FactoryBot.create(:game_user)
    expect(game_user).to be_valid
  end

  it 'has the correct associations' do
    game_user = FactoryBot.create(:game_user)
    expect(game_user.user).to be_a(User)
    expect(game_user.game).to be_a(Game)
  end
end
