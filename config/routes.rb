Rails.application.routes.draw do
  mount ActionCable.server => '/cable'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  scope :users do
    get '/index' => 'user#index'
    post '/create' => 'user#create'
  end

  scope :games do
    get '/check' => 'game#check'
    get '/index' => 'game#index'
    get '/:id/details' => 'game#details'
    get '/:id/view_initial' => 'game#view_initial'
    post '/create' => 'game#create'
    # get '/online_games' => 'game#online_games'
    get '/:id/user_play' => 'game#user_play'
    post '/:id/start_ack' => 'game#start_ack'
    put '/:id/quit' => 'game#quit'
  end

  scope :plays do
    get '/:game_id/index' => 'play#index'
    post '/:game_id/card_draw' => 'play#card_draw'
    put '/:game_id/discard_or_replace' => 'play#discard_or_replace'
    put '/:game_id/create_offloads' => 'play#create_offloads'
    put '/:game_id/create_powerplay' => 'play#create_powerplay'
    put '/:game_id/close_powerplay' => 'play#close_powerplay'
    put '/:game_id/showcards' => 'play#showcards'
  end


end
