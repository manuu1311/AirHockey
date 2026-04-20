extends CharacterBody2D

@export var start_position: Vector2
@export var player: int
@export var puck_path: NodePath
@onready var puck=get_node(puck_path)
@onready var collision_shape = $CollisionShape2D
#variable to lock the paddle movement in point start
var unlocked=false

#ai params
@export var reaction_time := 0.1
var timer := 0.0
var last_target : Vector2
@export var speed := 600.0
var home_position
@export var difficulty: int
var handle_ai: Callable
@export var middle_line: float

		
func reset():
	unlocked=false
	position= start_position
	last_target=position
	home_position=to_global(start_position)
	if difficulty == 0:
		handle_ai = Callable(self, "handle_ai_easy")
	elif difficulty == 1:
		handle_ai = Callable(self, "handle_ai_normal")
	
#move paddle
func _physics_process(delta):
	if GameState.game_state==GameState.GameStates.PLAYING or GameState.game_state==GameState.GameStates.ENDED:
		if player==0:
			handle_ai.call(delta)
		if player==1:
			handle_player(delta)
			
#player input handler
func handle_player(delta):
	var mouse_pos = get_global_mouse_position()
	if not unlocked:
		if collision_shape.shape.get_rect().has_point(to_local(mouse_pos)):
			unlocked=true
	else:
		velocity = (mouse_pos - global_position) / delta
		move_and_slide()
#handle ai movement
func handle_ai_easy(delta):
	if unlocked:
		timer += delta

		if timer >= reaction_time:
			timer = 0.0
			last_target = puck.global_position

		var direction = (last_target - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
	
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

		move_and_slide()
		
'''
func handle_ai_hard(delta):
	if unlocked:
		timer += delta

		if timer >= reaction_time:
			timer = 0.0
			
			var puck_pos = puck.global_position
			var puck_vel = puck.linear_velocity
			
			var goal_y = defense_line_y
			
			var is_threat = puck_vel.y < 0
			var will_hit_goal = false
			var predicted_x = puck_pos.x
			
			if is_threat:
				var time = (goal_y - puck_pos.y) / puck_vel.y
				predicted_x = puck_pos.x + puck_vel.x * time
				
				will_hit_goal = abs(predicted_x) < goal_width * 0.5
			
			if is_threat and will_hit_goal:
				# 🛡️ DEFEND
				last_target = Vector2(predicted_x, goal_y)
			
			elif puck_pos.y < 0:
				# ⚔️ ATTACK
				var attack_offset = Vector2(0, -20)
				last_target = puck_pos + attack_offset
			
			else:
				# 🧍 IDLE / RESET
				last_target = home_position
			
			# add imperfection
			last_target += Vector2(
				randf_range(-8, 8),
				randf_range(-8, 8)
			)

		var direction = (last_target - global_position).normalized()
		velocity = velocity.lerp(direction * speed, 0.15)

		move_and_slide()
'''	
