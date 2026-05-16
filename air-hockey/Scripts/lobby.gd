extends Node

const SIGNALING_URL = "ws://signaling.godot.community"


func _ready():
	WebRtcManager.game_ready.connect(_on_game_ready)
	Signaling.lobby_joined.connect(_on_lobby_joined)

func _on_host_pressed():
	var room_code = str(randi() % 9000 + 1000)  # e.g. "4821"
	Signaling.lobby = room_code
	Signaling.autojoin = true
	Signaling.connect_to_url(SIGNALING_URL)
	WebRtcManager.setup_host()
	#code_label.text = "Your code: %s" % room_code
	return room_code

func _on_join_pressed(code: String):
	var room_code = code.strip_edges()
	if room_code.length() == 0:
		return
	Signaling.lobby = room_code
	Signaling.autojoin = true
	Signaling.connect_to_url(SIGNALING_URL)
	WebRtcManager.setup_client()

func _on_lobby_joined(lobby: String):
	print("Joined lobby: ", lobby)

func _on_game_ready():
	# Both players connected — switch to game scene
	GameState.isMultiplayer=true
	get_tree().change_scene_to_file("res://Assets/Scene/Level/mainGame.tscn")
