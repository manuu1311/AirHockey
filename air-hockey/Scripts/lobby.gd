extends Node

const SIGNALING_URL = "wss://airhockey-h1ul.onrender.com"
@onready var code_label: Button = $"../background/CodeLabel"


func _ready():
	WebRtcManager.game_ready.connect(_on_game_ready)
	Signaling.lobby_joined.connect(_on_lobby_joined)

func _on_host_pressed():
	#var room_code = str(randi() % 9000 + 1000)  
	Signaling.lobby = ""
	Signaling.autojoin = true
	Signaling.connect_to_url(SIGNALING_URL)
	WebRtcManager.setup_host()
	code_label.text = "Connecting to server.." 

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
	code_label.text = "Room Code: \n%s" % lobby

func _on_game_ready():
	GameState.isMultiplayer = true
	if WebRtcManager._is_host:
		# Give Godot 1 frame to fully register the peer connection internally
		_call_start_game_deferred.call_deferred()
	
	
	
func _call_start_game_deferred():
	print("Host sending start_game RPC...")
	await get_tree().create_timer(1.5).timeout
	start_game.rpc()

func _switch_to_game():
	print("Switching scene to mainGame...")
	get_tree().change_scene_to_file("res://Assets/Scene/Level/mainGame.tscn")
	
@rpc("any_peer", "call_local", "reliable")
func start_game():
	print("start_game RPC received")
	_switch_to_game()
	
	
