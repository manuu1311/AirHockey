extends CharacterBody2D

@export var start_position: Vector2
@export var player: int

func reset():
	position= start_position*player
	
	
func _physics_process(delta):
	if player==1:
		var mouse_pos = get_global_mouse_position()
		
		velocity = (mouse_pos - global_position) / delta
		move_and_slide()
