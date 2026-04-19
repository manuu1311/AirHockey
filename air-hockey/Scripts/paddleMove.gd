extends CharacterBody2D

@export var start_position: Vector2
@export var player: int

func reset():
	position= start_position*player
	
	
func _physics_process(delta):
	if player==1:
		if GameState.game_state==GameState.GameStates.PLAYING or GameState.game_state==GameState.GameStates.ENDED:
			var mouse_pos = get_global_mouse_position()
			
			velocity = (mouse_pos - global_position) / delta
			move_and_slide()
