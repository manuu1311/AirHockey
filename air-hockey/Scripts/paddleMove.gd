extends CharacterBody2D

@export var start_position: Vector2
@export var player: int
@export var ai: bool
@export var puck_path: NodePath
@onready var puck=get_node(puck_path)
@onready var collision_shape = $CollisionShape2D
#variable to lock the paddle movement in point start
var unlocked=false
var maxspeed=7000

#ai params
@export var reaction_time := 0.1
var timer := 0.0
var last_target : Vector2
@export var speed := 600.0
var home_position
var handle_ai: Callable
@export var middle_line: float
@export var global_goal_line:= 870.0
@export var goal_width: Vector2
@export var debug:=false
#how fast a shot for it to be dangerous
var delta_dangerous:=0.5
#how slow the puck to be considered safe to attack
var attack_threshold:=500
@export var airl_path: NodePath 
var airl: Node2D
var airl_speed:=400


func _ready() -> void:
		home_position=to_global(start_position)
		if ai:
			if GameState.difficulty == 0:
				handle_ai = Callable(self, "handle_ai_easy")
			elif GameState.difficulty == 1:
				handle_ai = Callable(self, "handle_ai_normal")
			elif GameState.difficulty==2:
				handle_ai = Callable(self, "handle_ai_hard")
				#adjust parameters
				speed=600
				reaction_time=0.1
			elif GameState.difficulty==3:
				handle_ai = Callable(self, "handle_ai_rl")
				airl=get_node(airl_path)
		print('chosen difficulty ',GameState.difficulty)
			
		#goal_line=to_global(Vector2(0,goal_line)).y
		#convert relative x position of goal line to global positions
		#goal_width.x=to_global(Vector2(goal_width.x, 0)).x
		#goal_width.y=to_global(Vector2(goal_width.y, 0)).x
func reset():
	unlocked=false
	position= start_position
	last_target=position
	velocity=Vector2(0,0)
	if ai:
		if airl!=null:
			print('reward obtained by player ',player,': ',airl.reward)
			airl.done=true
		else:
			print('couldnt find airl :(')
#move paddle
func _physics_process(delta):
	if GameState.game_state==GameState.GameStates.PLAYING or GameState.game_state==GameState.GameStates.ENDED:
		if not ai:
			handle_player(delta)
		else:
			handle_ai.call(delta)
		velocity = velocity.limit_length(maxspeed)
		move_and_slide()
		#if training ai: detect collisions for reward
		if GameState.training and ai:
			passive_reward(delta)
			puck_position_rew(delta)

			
#player input handler
func handle_player(delta):
	var mouse_pos = get_global_mouse_position()
	if not unlocked:
		if collision_shape.shape.get_rect().has_point(to_local(mouse_pos)):
			unlocked=true
	else:
		velocity = (mouse_pos - global_position) / delta
#handle ai movement
func handle_ai_easy(delta):
	if unlocked:
		timer += delta

		if timer >= reaction_time:
			timer = 0.0
			last_target = puck.global_position

		var direction = (last_target - global_position).normalized()
		velocity = direction * speed
	
func handle_ai_normal(delta):
	if unlocked:
		timer += delta

		if timer >= reaction_time:
			timer = 0.0
			
			var prediction_time = 0.3
			var predicted_pos = puck.global_position + puck.linear_velocity * prediction_time
			if puck.global_position.y < middle_line:
				# DEFEND
				last_target = predicted_pos
			else:
				# RETURN HOME
				last_target = home_position
			
			#add imperfection
			last_target += Vector2(
				randf_range(-10, 10),
				randf_range(-10, 10)
			)

		var direction = (last_target - global_position).normalized()
		velocity = velocity.lerp(direction * speed, 0.1)
		
func handle_ai_hard(delta):
	if unlocked:
		timer += delta
		var temp_speed=speed
		if timer >= reaction_time:
			timer = 0.0
			
			var puck_pos = puck.global_position
			var puck_vel = puck.linear_velocity
			
			
			var is_coming = puck_vel.y < 0
			var is_dangerous = false
			var predicted_x = puck_pos.x
			#speed used to move, to be increased during attack
			
			if is_coming:
				var time = (global_goal_line - puck_pos.y) / puck_vel.y
				#out of reaction time: be careful!
				if time<delta_dangerous or position.y>puck_pos.y:
					is_dangerous=true
					#predict where puck is coming
					predicted_x = puck_pos.x + puck_vel.x * time
					#clamp x between the goal line
					predicted_x = clamp(predicted_x, 
										goal_width[0], 
										goal_width[1])
				

			if is_coming and is_dangerous:
				# DEFEND
				if debug:
					print('defending!')
				last_target = Vector2(predicted_x, global_goal_line)
			#if puck is in own field AND behind own paddle AND
			#is not going towards the opponent field "too fast" 
			#															add offset for zero division
			elif puck_pos.y<middle_line and puck_pos.y>position.y and abs(puck_vel.y) < attack_threshold:
				# ATTACK
				if debug:
					print('attacking!')
				var attack_offset = Vector2(0, -20)
				last_target = puck_pos + attack_offset
				temp_speed*=5
			
			else:
				# IDLE 
				if debug:
					print('resetting')
				last_target = home_position
			# add imperfection
			last_target += Vector2(
				randf_range(-8, 8),
				randf_range(-8, 8)
			)

		var direction = (last_target - global_position).normalized()
		velocity = velocity.lerp(direction * temp_speed, 0.15)

func handle_ai_rl(_delta):
	velocity.x=airl.move.x*airl_speed
	velocity.y=airl.move.y*airl_speed
	
#periodically give reward to agent depending on puck position
func puck_position_rew(delta:float):
	var sign_r
	if player==0:
		if puck.position.x>0:
			sign_r=-1
		else:
			sign_r=1
	elif player==1:
		if puck.position.x>0:
			sign_r=1
		else:
			sign_r=-1
	airl.puck_position_reward(sign_r, delta)
			
#passive negative reward to promote shorter points
func passive_reward(delta: float):
	airl.passive_reward(delta)
	
	
