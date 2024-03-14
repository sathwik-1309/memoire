RSpec.describe GameController, type: :controller do

  before :each do
    @user1 = create(:user)
    @user2 = create(:user)
    @user3 = create(:user)
    post :create, params: {player_ids: [@user1.id, @user2.id, @user3.id]}
    res = Oj.load(response.body)
    @game = Game.find_by_id(res['id'])
  end

  describe "GET #index" do
    it "returns all games" do
      post :create, params: {player_ids: [@user1.id, @user2.id, @user3.id]}
      get :index
      validate_response(response, 200)
      res = Oj.load(response.body)
      expect(res['games'].length).to eq(2)
    end

    it "returns only current_user games" do
      user4 = create(:user)
      post :create, params: {player_ids: [@user1.id, @user2.id, user4.id]}
      # set current_user as user4
      get :index
      validate_response(response, 200)
      res = Oj.load(response.body)
      expect(res['games'].length).to eq(1)
    end
  end

end