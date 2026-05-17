extends Node


@export var puck_path: NodePath
@export var uiPath: NodePath
@export var tablePath: NodePath
@onready var camera_2d: Camera2D = $"../Camera2D"
@onready var northPaddle: CharacterBody2D = $"../Table/PaddleN"
@onready var southPaddle: CharacterBody2D = $"../Table/PaddleS"


var puck
var goalSignal
var ui
var table
var playerScores: Array=[0,0]
var playerPuckVel: int

@export var winScore: int=5

#reset timer variables 
var reset_delay := 60.0
var reset_timer_id := 0



func _ready():
	print('readying')
	puck = get_node(puck_path)
	ui=get_node(uiPath)
	table=get_node(tablePath)
	ui.restartButtonPressedSignal.connect(onResetButton)
	table.goalScored.connect(GoalScored)
	print('training: ',GameState.training)
	print('difficulty: ',GameState.difficulty)
	playerPuckVel=1
	ResetBoard()
	#set multiplayer authorities
	if GameState.isMultiplayer:
		if WebRtcManager.is_host:
			multiplayer_aiflag_paddles.rpc()
			
	
@rpc("authority", "call_local", "reliable")
func multiplayer_aiflag_paddles():
	northPaddle.ai_flag=false
	southPaddle.ai_flag=false
	var client_id:=0
	if WebRtcManager.is_host:
		client_id = multiplayer.get_peers()[0]
	else:
		client_id = multiplayer.get_unique_id()
	print(client_id)
	puck.set_multiplayer_authority(1)
	southPaddle.set_multiplayer_authority(1)
	northPaddle.set_multiplayer_authority(client_id)
	if northPaddle.is_multiplayer_authority():
		camera_2d.rotation_degrees = 180
		camera_2d.offset = get_viewport().get_visible_rect().size
	
#routine after reset button is clicked
func onResetButton():
	#only host can reset
	if GameState.isMultiplayer and not WebRtcManager.is_host:
		return
	if GameState.game_state==GameState.GameStates.ENDED or GameState.training==true:
		playerScores=[0,0]
		ui.UpdateScore(playerScores)
	ResetBoard.rpc()
	
#reset the whole board before each point
@rpc("authority", "call_local", "reliable")
func ResetBoard(timeout=false):
	print('resetting board')
	if GameState.training:
		print('Resetting board')
		reset_timer_id += 1  
		#give puck to the ai
		#-1: north 1: south 0:no force
		#playerPuckVel=1
	start_reset_timer()  
	GameState.game_state=GameState.GameStates.COUNTDOWN
	ResetPaddles(timeout)
	puck.reset()
	if not GameState.training:
		ui.startCountdown()
		await ui.countdownFinished
	table.reset()
	GameState.game_state=GameState.GameStates.PLAYING
	#unlock ai paddles after countdown finish
	for paddle in [northPaddle,southPaddle]:
		if paddle.ai_flag==true:
			paddle.unlocked=true
	puck.apply_initial_force(playerPuckVel)
	#reset the paddle velocities
	northPaddle.velocity=Vector2.ZERO
	southPaddle.velocity=Vector2.ZERO
	
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
	#do nothing on client
	if GameState.isMultiplayer and not WebRtcManager.is_host:
		return
	playerPuckVel = 1 if player == 1 else -1
	if GameState.game_state==GameState.GameStates.PLAYING:
		IncreaseScore(player)
		puck.disappear()
		var has_won = playerScores[player] >= winScore
		if GameState.isMultiplayer:
			sync_goal_scored.rpc(player, playerScores, has_won)
		else:
			sync_goal_scored(player, playerScores, has_won)
	
@rpc("authority", "call_local", "reliable")
func sync_goal_scored(player: int, scores: Array, game_over: bool):
	playerScores = scores
	if WebRtcManager.is_host:
		ui.UpdateScore(playerScores)
	else:
		ui.UpdateScore([playerScores[1],playerScores[0]])
	puck.disappear()
	if game_over:
		GameState.game_state = GameState.GameStates.ENDED
		ui.endGame(player)
		puck.reset()
	else:
		newPoint()
		
#reset table and start new point
func newPoint():
	if WebRtcManager.is_host:
		if not GameState.training:
			await get_tree().create_timer(2).timeout
		ResetBoard.rpc()
	elif not GameState.isMultiplayer:
		if not GameState.training:
			await get_tree().create_timer(2).timeout
		ResetBoard()

func start_reset_timer():
	reset_timer_id += 1
	var my_id = reset_timer_id

	await get_tree().create_timer(reset_delay).timeout

	# only trigger if this is still the latest timer
	if my_id == reset_timer_id:
		ResetBoard(true)
