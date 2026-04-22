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
###rewards###
#reward for goal
@export var goal_reward: float= 1
#passive reward weight for puck position
@export var puck_position_weight: float=0.005
@export var passive_weight: float=0.002
@export var inference=true
#make observation symmetric
var x_mirrored: int


func _ready():
	table.goalScored.connect(goal_scored)
	max_puck_speed=puck.maxspeed
	max_paddle_speed=paddle.maxspeed
	player=paddle.player
	if player==0:
		x_mirrored =  1.0
	else: 
		x_mirrored = -1.0
	#print(paddle.position)
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
	obs.append(puck.linear_velocity.x / max_puck_speed)
	obs.append(puck.linear_velocity.y / max_puck_speed)

	obs.append(x_mirrored*paddle.velocity.x / max_paddle_speed)
	obs.append(paddle.velocity.y / max_paddle_speed)

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
func goal_scored(playerToScore: int):
	if player==playerToScore:
		reward+=goal_reward
	else:
		reward-=goal_reward

#passive reward for puck position (own side or opponent side)
func puck_position_reward(sign_r:int,delta:float):
	reward+=sign_r*puck_position_weight*delta

func passive_reward(delta:float):
	reward-=passive_weight*delta
	
#handle action computation
func get_action():
	if inference:
		var obs=get_obs()
		var modelOutput=ModelInference.forward(obs)
		move.x=modelOutput[0]
		move.y=modelOutput[1]
	return move
	
