extends CharacterBody2D

@export var start_position: Vector2
@export var player: int
@onready var collision_shape = $CollisionShape2D
#variable to lock the paddle movement in point start
var locked=true

func reset():
	locked=true
	position= start_position*player
	
	
func _physics_process(delta):
	if player==1:
		var mouse_pos = get_global_mouse_position()
		if GameState.game_state==GameState.GameStates.PLAYING or GameState.game_state==GameState.GameStates.ENDED:
			if locked:
				if collision_shape.shape.get_rect().has_point(to_local(mouse_pos)):
					locked=false
			else:
				velocity = (mouse_pos - global_position) / delta
				move_and_slide()
