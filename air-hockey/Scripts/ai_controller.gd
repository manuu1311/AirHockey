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
@export var goal_reward: float= 1
#passive reward weight for puck position
@export var puck_position_weight: float=0.00
@export var puck_velocity_weight: float=0.00
@export var passive_weight: float=0.000
@export var middle_weight:float = 0.00
@export var puck_distance_weight: float=0.000
@export var puck_hit_weight: float=0.0
@export var inference=true
@export var timeout:float=60
var simulated_time := 0.0
var inference_steps:int=0
@export var inference_action_repeat:int=5
var hit_puck:bool=false
var acc_rew:float=0



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
	simulated_time=0
	hit_puck=false
	acc_rew=0
	if inference: 
		inference_id=ModelInference.weighted_random_index(
			[1]
			)
		inference_action_repeat=ModelInference.action_repeat[inference_id]
		inference_steps=0
		if paddle.debug:
			print('inferencing with model ',inference_id,', action repeat: ',inference_action_repeat)
		
#-- Methods that need implementing using the "extend script" option in Godot --#
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
	var normalised_puckpos=puck.position
	normalised_puckpos.x/=field_width
	normalised_puckpos.y/=field_height
	var rel_goal = opponent_goal_position - normalised_puckpos
	obs.append(x_mirrored * rel_goal.x / (field_width*2))
	obs.append(rel_goal.y / (field_height*2))
	
	#scaled round time
	var time_norm = clamp(simulated_time / timeout, 0.0, 1.0)
	obs.append(time_norm)
	for i in range(len(obs)):
		if obs[i]<-1 or obs[i]>1:
			print('careful! obs out of bounds.. this is:\n',obs)
		obs[i]=clamp(obs[i],-1,1)
	return {"obs": obs}

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
	obs.append(x_mirrored*rel_puck.x / (field_width*2))
	obs.append(rel_puck.y / (field_height*2))
	#relative velocities
	var rel_vel = puck.linear_velocity - paddle.velocity
	obs.append(x_mirrored*rel_vel.y / (max_puck_speed+max_paddle_speed))
	obs.append(rel_vel.x / (max_puck_speed+max_paddle_speed))

	
	#scaled round time
	var time_norm = clamp(simulated_time / timeout, 0.0, 1.0)
	obs.append(time_norm)
	
	var check=false
	for i in range(len(obs)):
		if obs[i]<-1.2 or obs[i]>1.2:
			print('careful! obs out of bounds.. this is: ',obs)
			check=true
		obs[i]=clamp(obs[i],-1,1)
	if check and GameState.training:
		print('pucking out..')
		table.puckout()
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
		acc_rew+=goal_reward*scale_rew
	else:
		reward-=goal_reward*scale_rew/2
		acc_rew-=goal_reward*scale_rew/2
	if paddle.ai_training:
		print('reward obtained by player ',paddle.player,': ',acc_rew)
		if acc_rew<-1.5 or acc_rew>4:
			print('-- reward exceeded! careful! reward is: ',acc_rew)
	done=true

#passive reward for puck position (own side or opponent side)
func puck_position_reward(delta:float):
	#if x_mirrored*puck.position.x/field_width<-0.5 and abs(puck.position.y)/field_height<0.3:
	if x_mirrored*puck.position.x/field_width<-0.5:
		reward+=puck_position_weight*delta
		acc_rew+=puck_position_weight*delta
	elif x_mirrored*puck.position.x/field_width>0.65:
		reward-=puck_position_weight*delta
	'''
	var sign_r=0
	if x_mirrored*puck.position.x>=0: 
		sign_r=-1
	else:
		sign_r=1
	reward+=sign_r*puck_position_weight*delta
	'''
	

func puck_velocity_reward(delta:float):
	#if x_mirrored*puck.position.x/field_width>-0.1 and abs(puck.linear_velocity.length())<50:
#		reward-=10*puck_velocity_weight*delta
#		acc_rew-=10*puck_velocity_weight*delta
	if x_mirrored*puck.linear_velocity.y<-200:
		reward+=abs(puck.linear_velocity.length())*puck_velocity_weight*delta
		acc_rew+=abs(puck.linear_velocity.length())*puck_velocity_weight*delta
	#reward -= x_mirrored * puck.linear_velocity.y*puck_velocity_weight*delta
	#if puck is stuck in the middle: punish
	#if abs(last_puck_pos.x)<20 and abs(puck.position.x)<20:
	#	reward-=5*puck_velocity_weight*delta
	#else:
	#	reward -= x_mirrored * puck.linear_velocity.y*puck_velocity_weight*delta

func passive_reward(delta:float):
	simulated_time+=delta
	reward-=passive_weight*delta
	acc_rew-=passive_weight*delta
	
func middle_reward(delta:float):
	var pos= x_mirrored*paddle.position.x / field_width
	if pos<0.35:
		reward-=middle_weight*delta
		acc_rew-=middle_weight*delta

func puck_distance_reward(delta:float):
	var rel_puck = (puck.position - paddle.position)
	var dist = rel_puck.length()/(field_width*2)
	reward -=puck_distance_weight*dist*delta
	acc_rew -=puck_distance_weight*dist*delta
	
func puck_hit_reward():
	if hit_puck==false:
		reward+=puck_hit_weight
		acc_rew+=puck_hit_weight
		hit_puck=true
	else:
		reward+=puck_hit_weight/50
		acc_rew+=puck_hit_weight/50
	
	
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
func linear(W: Array, b: PackedFloat32Array, x: PackedFloat32Array, out_size: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(out_size)
	for i in range(out_size):
		var row: PackedFloat32Array = W[i]
		var sum: float = b[i]
		for j in range(x.size()):
			sum += row[j] * x[j]
		out[i] = sum
	return out


func tanh_vec(v: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(v.size())
	for i in range(v.size()):
		out[i] = tanh(v[i])
	return out
	
func linear_relu(W: Array, b: PackedFloat32Array, x: PackedFloat32Array, out_size: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(out_size)
	for i in range(out_size):
		var row: PackedFloat32Array = W[i]
		var sum: float = b[i]
		for j in range(x.size()):
			sum += row[j] * x[j]
		out[i] = sum if sum > 0.0 else 0.0
	return out
	
func forward(obs, params):
	var x := PackedFloat32Array(obs["obs"]) 

	# Layer 0: 17 -> 256
	var W0 = params["mlp_extractor.policy_net.0.weight"]
	var b0 = params["mlp_extractor.policy_net.0.bias"]
	#var h0 = relu_vec(add_bias(matvec(W0, x), b0))
	var h0 := linear_relu(W0, b0, x, 128)

	# Layer 1: 256 -> 256
	var W1 = params["mlp_extractor.policy_net.2.weight"]
	var b1 = params["mlp_extractor.policy_net.2.bias"]
	var h1 := linear_relu(W1, b1, h0, 128)
	

	# Output (mu): 256 -> 2
	var W2 = params["action_net.weight"]
	var b2 = params["action_net.bias"]
	var z3 := linear(W2, b2, h1, 2)

	# Deterministic action (SAC uses tanh squashing)
	#var action = tanh_vec(mu)
	var action=[]
	for a in z3:
		action.append(clamp(a, -1.0, 1.0))

	return action
'''
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
'''


func _on_puck_body_entered(body: Node) -> void:
	if body==paddle:
		puck_hit_reward()
