extends Node

var left_score := 0
var right_score := 0

@export var puck_path: NodePath
@export var northPaddlePath: NodePath
@export var southPaddlePath: NodePath
@export var uiPath: NodePath


var puck
var northPaddle
var southPaddle
var goalSignal
var ui
var playerScores: Array=[0,0]

func _ready():
	puck = get_node(puck_path)
	northPaddle = get_node(northPaddlePath)
	southPaddle = get_node(southPaddlePath)
	ui=get_node(uiPath)
	ui.restartButtonPressedSignal.connect(ResetBoard)

	
#reset the whole board before each point
func ResetBoard():
	ResetPaddles()
	puck.reset()
	
#reset paddles to their starting positions
func ResetPaddles():
	northPaddle.reset()
	southPaddle.reset()
#increase score for the given player (int 1, -1)
func IncreaseScore(player: int):
	playerScores[player]+=1
	ui.update(playerScores)
