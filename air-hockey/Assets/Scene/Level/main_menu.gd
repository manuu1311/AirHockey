extends Control



func _on_button_pressed(difficulty: int) -> void:
	GameState.difficulty=difficulty
	next_state()
	
func next_state():
	get_tree().change_scene_to_file("res://Assets/Scene/Level/mainGame.tscn")
