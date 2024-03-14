# frozen_string_literal: true

RSpec.describe User, type: :model do
  it 'has a valid factory' do
    user = FactoryBot.create(:user)
    expect(user).to be_valid
  end
end
