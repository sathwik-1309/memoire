SUITS = ['♠','♥','♦','♣']
VALUES = ['A','2','3','4','5','6','7','8','9','10','J','Q','K']

# status
FINISHED = "finished"
ONGOING = "ongoing"
DEAD = "dead"
NEW = "new"

# stages
SHOW_CARDS = "show_cards"
CARD_DRAW = "card_draw"
DOR = "discard_or_replace"
OFFLOADS = "offloads"
POWERPLAY = "powerplay"
INITIAL_VIEW = "initial_view"
START_ACK = "start_ack"

# game user status
GAME_USER_START_ACK = "start_ack"
GAME_USER_WAITING_TO_JOIN = "waiting"
GAME_USER_IS_PLAYING = "playing"
GAME_USER_FINISHED = "finished"
GAME_USER_QUIT = "quit"

SELF_OFFLOAD = "self offload"
CROSS_OFFLOAD = "cross offload"

#powerplays
SWAP_CARDS = "swap_cards"
VIEW_SELF = "view_self"
VIEW_OTHERS = "view_others"

#card draw actions
REPLACE = "replace"
DISCARD = "discard"


POWERPLAY_CARD_VALUES = ['7','8','9','10','J','Q']

# channels
USER_CHANNEL = "user_channel"
GAME_CHANNEL = "game_channel"

TIMEOUT_IV = 20
TIMEOUT_CD = 20
TIMEOUT_DOR = 20
TIMEOUT_PP = 10
TIMEOUT_OFFLOAD = 20
FINSIHED_SLEEP = 15