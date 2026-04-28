extends CharacterBody2D

@export var start_position: Vector2
@export var player: int
@export var ai_flag: bool
@export var puck_path: NodePath
@onready var puck=get_node(puck_path)
@onready var collision_shape = $CollisionShape2D
@export var difficulty: int = -1
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
var direction := 1
#how fast a shot for it to be dangerous
var delta_dangerous:=0.5
#how slow the puck to be considered safe to attack
var attack_threshold:=500
@export var airl_path: NodePath 
var airl: Node2D
var airl_speed:=400
@export var ai_training:bool


func _ready() -> void:
	if difficulty==-1:
		difficulty=GameState.difficulty
	home_position=to_global(start_position)
	if difficulty == 0:
		handle_ai = Callable(self, "handle_ai_easy")
	elif difficulty == 1:
		handle_ai = Callable(self, "handle_ai_normal")
	elif difficulty==2:
		handle_ai = Callable(self, "handle_ai_hard")
		#adjust parameters
		speed=600
		reaction_time=0.1
	elif difficulty==4:
		#random dummy movements
		var weights=[0.5,1,1]
		var id =weighted_random_index(weights)
		if id==0:
			handle_ai = Callable(self, "handle_ai_dummy")
		elif id==1:
			handle_ai = Callable(self, "handle_ai_stupid")
			#make it hover in the middle
			timer=0.15
		elif id==2:
			handle_ai = Callable(self, "handle_ai_still")
			
	if difficulty==3 or ai_training:
		print('handle rl!')
		handle_ai = Callable(self, "handle_ai_rl")
		airl=get_node(airl_path)
		
func reset(timeout=false):
	unlocked=false
	position= start_position
	last_target=position	
	velocity=Vector2(0,0)
	if ai_training:
		print('reward obtained by player ',player,': ',airl.reward)
		airl.done=true
		if timeout:
			airl.goal_scored(2,0.5)
	if airl!=null:
		airl.reset()
	'''
	if ai_flag:
		if airl!=null:
			if timeout:
				airl.goal_scored(2,1.5)
			print('reward obtained by player ',player,': ',airl.reward)
			airl.done=true
		else:
			print('couldnt find airl: no reward!')
	if ai_flag and not ai_training:
		#if training, randomise difficulties
		if GameState.training==true:
			var weights=[0.3,0.3,0.3,0.0,1]
			GameState.difficulty =weighted_random_index(weights)
			print('Difficulty changed to ',GameState.difficulty)
		if GameState.difficulty == 0:
			handle_ai = Callable(self, "handle_ai_easy")
		elif GameState.difficulty == 1:
			handle_ai = Callable(self, "handle_ai_normal")
		elif GameState.difficulty==2:
			handle_ai = Callable(self, "handle_ai_hard")
			#adjust parameters
			speed=600
			reaction_time=0.1
		elif GameState.difficulty==3 or ai_training:
			handle_ai = Callable(self, "handle_ai_rl")
			airl=get_node(airl_path)
		elif GameState.difficulty==4:
			handle_ai=Callable(self,"handle_ai_dummy")
			'''
#move paddle
func _physics_process(delta):
	if GameState.game_state==GameState.GameStates.PLAYING or GameState.game_state==GameState.GameStates.ENDED:
		if not ai_flag:
			handle_player(delta)
		else:
			handle_ai.call(delta)
		velocity = velocity.limit_length(maxspeed)
		move_and_slide()
		#if training ai: detect collisions for reward
		if GameState.training and ai_flag and ai_training:
			passive_reward(delta)
			puck_position_rew(delta)
			puck_velocity_rew(delta)
			#middle_reward(delta)
			puck_distance_reward(delta)

			
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
			elif puck_pos.y<middle_line-50 and puck_pos.y>position.y and abs(puck_vel.y) < attack_threshold:
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
	var move=airl.get_action()
	velocity.x=move.x*airl_speed
	velocity.y=move.y*airl_speed*airl.x_mirrored
	
#periodically give reward to agent depending on puck position
func puck_position_rew(delta:float):
	'''
	var sign_r
	var check=false
	if player==0:
		if puck.position.x>0.2:
			sign_r=-1
			check=true
		elif puck.position.x<-0.2:
			sign_r=1
			check=true
	elif player==1:
		if puck.position.x>0.2:
			sign_r=1
			check=true
		elif puck.position.x<-0.2:
			sign_r=-1
			check=true
	if check:
		airl.puck_position_reward(sign_r, delta)
		'''
	airl.puck_position_reward(delta)	
#passive negative reward to promote shorter points
func passive_reward(delta: float):
	airl.passive_reward(delta)

func puck_velocity_rew(delta: float):
	airl.puck_velocity_reward(delta)
func middle_reward(delta: float):
	airl.middle_reward(delta)
func puck_distance_reward(delta):
	airl.puck_distance_reward(delta)
#random weighted distribution
func weighted_random_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w

	var r := randf() * total
	var cumulative := 0.0

	for i in range(weights.size()):
		cumulative += weights[i]
		if r < cumulative:
			return i

	return weights.size() - 1  
	
	
func handle_ai_dummy(_delta):
	velocity = Vector2(300,300)

func handle_ai_stupid(delta):
	timer += delta
	
	if timer >= 0.3:
		timer = 0
		direction *= -1  # flip between 1 and -1
	
	velocity.x = direction * 200
	#velocity.y=direction*75
		
func handle_ai_still(_delta):
	return
