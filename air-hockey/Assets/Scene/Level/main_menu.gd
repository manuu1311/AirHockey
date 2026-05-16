extends Control

@onready var single_player: VBoxContainer = $background/SinglePlayer
@onready var multi_player: VBoxContainer = $background/MultiPlayer
@onready var main: VBoxContainer = $background/Main
@onready var back_button: Button = $background/BackButton
@onready var code_input: LineEdit = $background/MultiPlayer/VBoxContainer/CodeInput
@onready var code_label: Button = $background/CodeLabel
@onready var lobby: Node = $Lobby
var inLobby=false

func _ready() -> void:
	main.show()
	single_player.hide()
	multi_player.hide()
	back_button.hide()
	code_label.hide()

#easy, ...,mlagent buttons
func _on_difficulty_pressed(difficulty: int) -> void:
	GameState.difficulty=difficulty
	next_state()

#0=single player, 1=multiplayer
func _on_mode_pressed(mode: int) -> void:
	if mode==0:
		single_player.show()
	elif mode==1:
		multi_player.show()
	main.hide()
	back_button.show()

func next_state():
	get_tree().change_scene_to_file("res://Assets/Scene/Level/mainGame.tscn")


func _on_back_button_pressed() -> void:
	multi_player.hide()
	single_player.hide()
	back_button.hide()
	main.show()
	code_label.hide()
	if inLobby:
		#WebRtcManager.leave()
		inLobby=false

func _on_host_button_pressed()-> void:
	print('host button pressed')
	lobby._on_host_pressed()
	#code_label.text = "Your code: %s" % room_code
	code_label.show()
	multi_player.hide()
	inLobby=true
	
func _on_join_button_pressed(_text='')-> void:
	print('join button pressed, input: ',code_input.text)
	lobby._on_join_pressed(code_input.text)
	code_input.text=''


func _on_code_label_pressed() -> void:
	var parts = code_label.text.split("\n")
	if len(parts)>1:
		var lobby_code = parts[1]
		DisplayServer.clipboard_set(lobby_code)
