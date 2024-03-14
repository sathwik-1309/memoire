# frozen_string_literal: true

RSpec.describe Play, type: :model do
  it 'has a valid factory' do
    play = FactoryBot.create(:play)
    expect(play).to be_valid
  end

  it 'has the correct associations' do
    play = FactoryBot.create(:play)
    expect(play.game).to be_a(Game)
  end
end
