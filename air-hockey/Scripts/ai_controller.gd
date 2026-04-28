extends AIController2D

var move:= Vector2.ZERO	
@onready var table: Sprite2D = $"../.."
@export var paddle: CharacterBody2D 
@export var opponent: CharacterBody2D 
@export var puck: RigidBody2D 
@export var field_width: float=860
@export var field_height: float=490
var max_puck_speed: float
var max_paddle_speed: float
var player: int
var last_puck_pos : Vector2 = Vector2.ZERO
###rewards###
#reward for goal
@export var goal_reward: float= 3
#passive reward weight for puck position
@export var puck_position_weight: float=0.005
@export var puck_velocity_weight: float=0.005
@export var passive_weight: float=0.001
@export var middle_weight:float = 0.005
@export var puck_distance_weight: float=0.005
@export var inference=true

#make observation symmetric
var x_mirrored: int


func _ready():
	table.goalScored.connect(goal_scored)
	max_puck_speed=puck.maxspeed
	max_paddle_speed=paddle.maxspeed
	player=paddle.player
	if player==0:
		x_mirrored =  1
	else: 
		x_mirrored = -1
	#divide reward weight by max puck speed
	puck_velocity_weight/=max_puck_speed
	#halve length and height to normalise between -1 and 1
	field_height/=2
	field_width/=2
	
func reset():
	reward=0
	if inference: 
		ModelInference.initialise()
#-- Methods that need implementing using the "extend script" option in Godot --#
func get_obs() -> Dictionary:
	var obs = []

	# normalised positions
	obs.append(x_mirrored*paddle.position.x / field_width)
	obs.append(paddle.position.y / field_height)

	obs.append(x_mirrored*puck.position.x / field_width)
	obs.append(puck.position.y / field_height)

	obs.append(x_mirrored*opponent.position.x / field_width)
	obs.append(opponent.position.y / field_height)

	# normalised velocities
	#flip x and y!! velocity is in world space
	obs.append(x_mirrored*puck.linear_velocity.y / max_puck_speed)
	obs.append(puck.linear_velocity.x / max_puck_speed)
	#flip x and y!! velocity is in world space
	obs.append(x_mirrored*paddle.velocity.y / max_paddle_speed)
	obs.append(paddle.velocity.x / max_paddle_speed)
	
	#puck history: calculate how much the puck moved since last frame
	var puck_delta = puck.position - last_puck_pos
	obs.append(x_mirrored * puck_delta.x / 50.0) 
	obs.append(puck_delta.y / 50.0)	 
	# update for next frame
	last_puck_pos = puck.position

	# relative positions
	var rel_puck = (puck.position - paddle.position)
	obs.append(x_mirrored*rel_puck.x / field_width)
	obs.append(rel_puck.y / field_height)
	return {"obs": obs}


func get_reward() -> float:
	return reward


func get_action_space() -> Dictionary:
	return {
		"move": {"size": 2, "action_type": "continuous"},
	}


func set_action(action) -> void:
	move.x=action['move'][0]
	move.y=action['move'][1]
	

#goal scored signal
func goal_scored(playerToScore: int,scale_rew: float=1):
	if player==playerToScore:
		reward+=goal_reward*scale_rew
	else:
		reward-=goal_reward*scale_rew/3

#passive reward for puck position (own side or opponent side)
func puck_position_reward(_delta:float):
	var sign_r=0
	if x_mirrored*puck.position.x>=0: 
		sign_r=-1
	else:
		sign_r=1
	reward+=sign_r*puck_position_weight
	

func puck_velocity_reward(_delta:float):
	#if puck is stuck in the middle: punish
	if abs(last_puck_pos.x)<20 and abs(puck.position.x)<20:
		reward-=20*puck_velocity_weight
	else:
		reward -= x_mirrored * puck.linear_velocity.y*puck_velocity_weight

func passive_reward(_delta:float):
	reward-=passive_weight
	
func middle_reward(_delta:float):
	var pos= x_mirrored*paddle.position.x / field_width
	if pos<0.35:
		reward-=middle_weight

func puck_distance_reward(_delta:float):
	var rel_puck = (puck.position - paddle.position)
	var dist = rel_puck.length()/field_width
	reward -=dist * puck_distance_weight
	
	
#handle action computation
func get_action():
	if inference:
		var obs=get_obs()
		var modelOutput=ModelInference.forward(obs)
		move.x=modelOutput[0]
		move.y=modelOutput[1]
	return move
	
