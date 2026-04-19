extends Node


#game states
enum GameStates { COUNTDOWN, PLAYING, PAUSED, ENDED }
var game_state : GameStates=GameStates.ENDED
