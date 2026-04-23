extends Node


@export var puck_path: NodePath
@export var northPaddlePath: NodePath
@export var southPaddlePath: NodePath
@export var uiPath: NodePath
@export var tablePath: NodePath


var puck
var northPaddle
var southPaddle
var goalSignal
var ui
var table
var playerScores: Array=[0,0]

@export var winScore: int=5
@export var training: bool

#reset timer variables 
var reset_delay := 60.0
var reset_timer_id := 0


func _ready():
	puck = get_node(puck_path)
	northPaddle = get_node(northPaddlePath)
	southPaddle = get_node(southPaddlePath)
	ui=get_node(uiPath)
	table=get_node(tablePath)
	ui.restartButtonPressedSignal.connect(onResetButton)
	table.goalScored.connect(GoalScored)
	GameState.training=training
	print('training: ',GameState.training)
	print('difficulty: ',GameState.difficulty)
	ResetBoard()

#routine after reset button is clicked
func onResetButton():
	if GameState.game_state==GameState.GameStates.ENDED or GameState.training==true:
		playerScores=[0,0]
		ui.UpdateScore(playerScores)
	ResetBoard()
	
#reset the whole board before each point
func ResetBoard(timeout=false):
	if GameState.training==true:
		print('Resetting board')
		reset_timer_id += 1  
	start_reset_timer()  
	GameState.game_state=GameState.GameStates.COUNTDOWN
	ResetPaddles(timeout)
	puck.reset()
	if GameState.training==false:
		ui.startCountdown()
		await ui.countdownFinished
	GameState.game_state=GameState.GameStates.PLAYING
	#unlock ai paddles after countdown finish
	for paddle in [northPaddle,southPaddle]:
		if paddle.ai_flag==true:
			paddle.unlocked=true
	
#reset paddles to their starting positions
func ResetPaddles(timeout:bool):
	northPaddle.reset(timeout)
	southPaddle.reset(timeout)
	
#increase score for the given player (int 1, -1)
func IncreaseScore(player: int):
	if GameState.training==false:
		playerScores[player]+=1
		ui.UpdateScore(playerScores)
	
#function called on signal emitted from goal lines
func GoalScored(player:int):
	if GameState.game_state==GameState.GameStates.PLAYING:
		IncreaseScore(player)
		puck.disappear()
		if playerScores[player]>=winScore:
			print("Player %d won the game",player)
			GameState.game_state=GameState.GameStates.ENDED
			ui.endGame(player)
			puck.reset()
		else:
			newPoint()
	
#reset table and start new point
func newPoint():
	if GameState.training==false:
		await get_tree().create_timer(2).timeout
	ResetBoard()

func start_reset_timer():
	reset_timer_id += 1
	var my_id = reset_timer_id

	await get_tree().create_timer(reset_delay).timeout

	# only trigger if this is still the latest timer
	if my_id == reset_timer_id:
		ResetBoard(true)
