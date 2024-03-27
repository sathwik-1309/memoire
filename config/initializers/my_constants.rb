SUITS = %w[♠ ♥ ♦ ♣]
VALUES = %w[A 2 3 4 5 6 7 8 9 10 J Q K]

# game status
START_ACK = "start_ack"
FINISHED = "finished"
ONGOING = "ongoing"
DEAD = "dead"
NEW = "new"

# game stages
CARD_DRAW = "card_draw"
DOR = "discard"
OFFLOADS = "offloads"
POWERPLAY = "powerplay"
INITIAL_VIEW = "initial_view"
START_ACK = "start_ack"

# game user status
GAME_USER_START_ACK = "start_ack"
GAME_USER_WAITING = "waiting"
GAME_USER_IS_PLAYING = "playing"
GAME_USER_FINISHED = "finished"
GAME_USER_QUIT = "quit"

# offload types
SELF_OFFLOAD = "self offload"
CROSS_OFFLOAD = "cross offload"

# powerplay types
SWAP_CARDS = "swap_cards"
VIEW_SELF = "view_self"
VIEW_OTHERS = "view_others"

#card draw actions
REPLACE = "replace"
DISCARD = "discard"

# powerplay cards
POWERPLAY_CARD_VALUES = %w[7 8 9 10 J Q]
NORMAL_CARD_VALUES = %w[A 2 3 4 5 6]

# channels
USER_CHANNEL = "user_channel"
GAME_CHANNEL = "game_channel"


# timeouts
TIMEOUT_IV = 20
TIMEOUT_CD = 20
TIMEOUT_DOR = 20
TIMEOUT_PP = 10
TIMEOUT_OFFLOAD = 20
FINISHED_SLEEP = 30

# backend url
BACKEND_URL = "http://localhost:3000"

# api methods
GET_API = 'get'
POST_API = 'post'
PUT_API = 'put'
DELETE_API = 'delete'