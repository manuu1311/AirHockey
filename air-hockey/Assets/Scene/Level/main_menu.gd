extends Control

@onready var single_player: VBoxContainer = $background/SinglePlayer
@onready var multi_player:  VBoxContainer = $background/MultiPlayer
@onready var main:          VBoxContainer = $background/Main
@onready var back_button:   Button        = $background/BackButton
@onready var code_input:    LineEdit      = $background/MultiPlayer/VBoxContainer/CodeInput
@onready var code_label:    Button        = $background/CodeLabel

var inLobby := false


func _ready() -> void:
	main.show()
	single_player.hide()
	multi_player.hide()
	back_button.hide()
	code_label.hide()

	# Wire NetworkManager signals once, here, so they're always connected
	WebRtcManager.signal_lobby_created.connect(_on_lobby_created)
	WebRtcManager.signal_lobby_joined.connect(_on_lobby_joined)
	WebRtcManager.signal_game_ready.connect(_on_game_ready)
	WebRtcManager.signal_client_disconnected.connect(_on_disconnected)


# ── Difficulty / mode buttons ──────────────────────────────────────────────────

func _on_difficulty_pressed(difficulty: int) -> void:
	GameState.difficulty = difficulty
	next_state()

# 0 = single player, 1 = multiplayer
func _on_mode_pressed(mode: int) -> void:
	if mode == 0:
		single_player.show()
	elif mode == 1:
		multi_player.show()
	main.hide()
	back_button.show()


# ── Navigation ─────────────────────────────────────────────────────────────────

func next_state() -> void:
	get_tree().change_scene_to_file("res://Assets/Scene/Level/mainGame.tscn")

func _on_back_button_pressed() -> void:
	multi_player.hide()
	single_player.hide()
	back_button.hide()
	code_label.hide()
	main.show()
	if inLobby:
		WebRtcManager.disconnect_from_server()
		inLobby = false


# ── Multiplayer buttons ────────────────────────────────────────────────────────

func _on_host_button_pressed() -> void:
	print("Host button pressed")
	code_label.text = "Waiting for code…"
	code_label.show()
	multi_player.hide()
	inLobby = true
	WebRtcManager.lobby_host()

func _on_join_button_pressed(_text: String = "") -> void:
	var code := code_input.text.strip_edges()
	print("Join button pressed, code: ", code)
	if code.is_empty():
		return
	code_input.text = ""
	inLobby = true
	WebRtcManager.lobby_join(code)

func _on_code_label_pressed() -> void:
	# Label text is "Your code:\nABCD1234" – copy just the code line
	var parts = code_label.text.split("\n")
	if parts.size() > 1:
		DisplayServer.clipboard_set(parts[1])


# ── NetworkManager signal handlers ────────────────────────────────────────────

func _on_lobby_created(code: String) -> void:
	# Two-line format so _on_code_label_pressed can split off the code
	code_label.text = "Your code:\n%s" % code
	print("Lobby created: ", code)

func _on_lobby_joined() -> void:
	code_label.text = "Joined!\nWaiting for host…"
	code_label.show()
	multi_player.hide()
	print("Lobby joined – waiting for WebRTC…")

func _on_game_ready() -> void:
	print("Game ready – starting!")
	next_state()

func _on_disconnected() -> void:
	# Only react if we're still on this screen (not already in-game)
	if inLobby:
		inLobby = false
		code_label.hide()
		multi_player.hide()
		back_button.hide()
		main.show()
		print("Disconnected from server")
