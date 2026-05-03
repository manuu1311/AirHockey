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
var opponent_goal_position=Vector2(-1,0.5)
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
@export var inference_action_repeat:int=5


#make observation symmetric
var x_mirrored: int
#inference model id
var inference_id:int


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
		inference_id=ModelInference.weighted_random_index([0,0,0,0,1])
		if paddle.debug:
			print('inferencing with model ',inference_id)
		
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
	#normalised velocity direction
	#var puck_dir = puck.linear_velocity.normalized()
	#obs.append(x_mirrored * puck_dir.y)
	#obs.append(puck_dir.x)
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
	obs.append(x_mirrored*rel_puck.x / (field_width*2))
	obs.append(rel_puck.y / (field_height*2))
	#normalised direction vector to puck
	#var dir_to_puck = rel_puck.normalized()
	#obs.append(x_mirrored * dir_to_puck.x)
	#obs.append(dir_to_puck.y)
	#relative velocities
	var rel_vel = puck.linear_velocity - paddle.velocity
	obs.append(x_mirrored*rel_vel.y / (max_puck_speed+max_paddle_speed))
	obs.append(rel_vel.x / (max_puck_speed+max_paddle_speed))
	#relative direction to goal
	var rel_goal = opponent_goal_position - puck.position
	obs.append(x_mirrored * rel_goal.x / field_width)
	obs.append(rel_goal.y / field_height)
	
	#scaled round time
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - round_start_time
	var time_norm = clamp(elapsed / timeout, 0.0, 1.0)
	obs.append(time_norm)
	return {"obs": obs}

func get_obs_legacy() -> Dictionary:
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
	if x_mirrored*puck.position.x/field_width<-0.5 and abs(puck.position.y)/field_height<0.3:
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
	if x_mirrored*puck.position.x/field_width>-0.1 and abs(puck.linear_velocity.length())<200:
		reward-=puck_velocity_weight
	elif x_mirrored*puck.linear_velocity.y<-200:
		reward+=abs(puck.linear_velocity.length()/puck.maxspeed)*puck_velocity_weight*delta
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
	var dist = rel_puck.length()/(field_width*2)
	reward +=puck_distance_weight*(1-dist)*delta
	
	
#handle action computation
func get_action():
	if inference:
		inference_steps+=1
		if inference_steps==inference_action_repeat:
			inference_steps=0
			var modelOutput=inference_predict()
			move.x=modelOutput[0]
			move.y=modelOutput[1]
	return move
	
#inference
func inference_predict():
	return forward(get_obs(),ModelInference.params[inference_id])
	
#define basic mlp functions
func matvec(W, x):
	var out = []
	for i in range(W.size()): # rows
		var sum = 0.0
		for j in range(x.size()):
			sum += W[i][j] * x[j]
		out.append(sum)
	return out


func add_bias(v, b):
	var out = []
	for i in range(v.size()):
		out.append(v[i] + b[i])
	return out


func tanh_vec(v):
	var out = []
	for i in range(v.size()):
		out.append(tanh(v[i]))
	return out
	
func relu_vec(v):
	var out = []
	for i in range(v.size()):
		out.append(max(0.0, v[i]))
	return out
	
func forward(obs, params):
	var x = obs["obs"]  # should be size 23

	# Layer 0: 23 -> 128
	var W0 = params["latent_pi.0.weight"]
	var b0 = params["latent_pi.0.bias"]
	var h0 = relu_vec(add_bias(matvec(W0, x), b0))

	# Layer 1: 128 -> 128
	var W1 = params["latent_pi.2.weight"]
	var b1 = params["latent_pi.2.bias"]
	var h1 = relu_vec(add_bias(matvec(W1, h0), b1))

	# Layer 2: 128 -> 128
	var W2 = params["latent_pi.4.weight"]
	var b2 = params["latent_pi.4.bias"]
	var h2 = relu_vec(add_bias(matvec(W2, h1), b2))

	# Output (mu): 128 -> 2
	var W_mu = params["mu.weight"]
	var b_mu = params["mu.bias"]
	var mu = add_bias(matvec(W_mu, h2), b_mu)

	# Deterministic action (SAC uses tanh squashing)
	var action = tanh_vec(mu)

	return action

#inference
func forward_ppo(obs,params):
	var W0 = params["mlp_extractor.policy_net.0.weight"]
	var b0 = params["mlp_extractor.policy_net.0.bias"]

	var W1 = params["mlp_extractor.policy_net.2.weight"]
	var b1 = params["mlp_extractor.policy_net.2.bias"]

	var W2 = params["action_net.weight"]
	var b2 = params["action_net.bias"]
	# Layer 1: 12 -> 64
	var z1 = matvec(W0, obs['obs'])
	z1 = add_bias(z1, b0)
	var a1 = tanh_vec(z1)

	# Layer 2: 64 -> 64
	var z2 = matvec(W1, a1)
	z2 = add_bias(z2, b1)
	var a2 = tanh_vec(z2)

	# Output: 64 -> 2
	var z3 = matvec(W2, a2)
	z3 = add_bias(z3, b2)
	var action = []
	for x in z3:
		action.append(clamp(x, -1.0, 1.0))
	return action
	
