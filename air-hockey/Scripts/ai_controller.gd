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
var last_opponent_pos : Vector2 = Vector2.ZERO
var last_paddle_pos : Vector2 = Vector2.ZERO
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
@export var timeout:float=60
var round_start_time := 0.0
var inference_steps:int=0
@export var inference_action_repeat:int=4

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
	
func reset_inference():
	round_start_time = Time.get_ticks_msec() / 1000.0
	if inference: 
		ModelInference.initialise()
		
#-- Methods that need implementing using the "extend script" option in Godot --#
func get_obs() -> Dictionary:
	var obs:Array[float]= []

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
	#flip x and y!! velocity is in world space
	obs.append(x_mirrored*opponent.velocity.y / max_paddle_speed)
	obs.append(opponent.velocity.x / max_paddle_speed)
	
	'''
	#puck history: calculate how much the puck moved since last frame
	var puck_delta = puck.position - last_puck_pos
	obs.append(x_mirrored * puck_delta.x / 50.0) 
	obs.append(puck_delta.y / 50.0)	 
	# update for next frame
	last_puck_pos = puck.position
	
	#paddle history: calculate how much the paddle moved since last frame
	var paddle_delta = paddle.position - last_paddle_pos
	obs.append(x_mirrored * paddle_delta.x / 50.0) 
	obs.append(paddle_delta.y / 50.0)	 
	# update for next frame
	last_paddle_pos = paddle.position
	
	#opponent history: calculate how much the paddle moved since last frame
	var opponent_delta = opponent.position - last_opponent_pos
	obs.append(x_mirrored * opponent_delta.x / 50.0) 
	obs.append(opponent_delta.y / 50.0)	 
	# update for next frame
	last_opponent_pos = opponent.position
	'''

	# relative positions
	var rel_puck = (puck.position - paddle.position)
	obs.append(x_mirrored*rel_puck.x / field_width)
	obs.append(rel_puck.y / field_height)
	#relative velocities
	var rel_vel = puck.linear_velocity - paddle.velocity
	obs.append(x_mirrored*rel_vel.y / (max_puck_speed+max_paddle_speed))
	obs.append(rel_vel.x / (max_puck_speed+max_paddle_speed))
	
	#scaled round time
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - round_start_time
	var time_norm = clamp(elapsed / timeout, 0.0, 1.0)
	obs.append(time_norm)
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
func goal_scored(playerToScore: int, scale_rew:float=1):
	if player==playerToScore:
		reward+=goal_reward*scale_rew
	else:
		reward-=goal_reward*scale_rew/2
	done=true
	needs_reset=true
	reset()

#passive reward for puck position (own side or opponent side)
func puck_position_reward(delta:float):
	if puck.position.x<-0.7 and abs(puck.position.y)<0.4:
		reward+=puck_position_weight*delta
	'''
	var sign_r=0
	if x_mirrored*puck.position.x>=0: 
		sign_r=-1
	else:
		sign_r=1
	reward+=sign_r*puck_position_weight*delta
	'''
	

func puck_velocity_reward(delta:float):
	if puck.linear_velocity.y<0:
		reward+=puck.linear_velocity.length()/puck.maxspeed*puck_velocity_weight*delta
	#reward -= x_mirrored * puck.linear_velocity.y*puck_velocity_weight*delta
	#if puck is stuck in the middle: punish
	#if abs(last_puck_pos.x)<20 and abs(puck.position.x)<20:
	#	reward-=5*puck_velocity_weight*delta
	#else:
	#	reward -= x_mirrored * puck.linear_velocity.y*puck_velocity_weight*delta

func passive_reward(delta:float):
	reward-=passive_weight*delta
	
func middle_reward(delta:float):
	var pos= x_mirrored*paddle.position.x / field_width
	if pos<0.35:
		reward-=middle_weight*delta

func puck_distance_reward(delta:float):
	var rel_puck = (puck.position - paddle.position)
	var dist = rel_puck.length()/field_width
	reward +=puck_distance_weight*(1-dist)*delta
	
	
#handle action computation
func get_action():
	if inference:
		inference_steps+=1
		if inference_steps==inference_action_repeat:
			inference_steps=0
			var obs=get_obs()
			var modelOutput=ModelInference.forward(obs)
			move.x=modelOutput[0]
			move.y=modelOutput[1]
	return move
	
