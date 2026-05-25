extends CanvasLayer


@onready var scoren= $UI/ScoreN
@onready var scores= $UI/ScoreS
@onready var countdownLabel= $UI/Countdown
@onready var finalTextLabel= $UI/FinalText
signal restartButtonPressedSignal
signal countdownFinished
signal musicOff

func _ready() -> void:
	countdownLabel.hide()
	finalTextLabel.hide()
	
#increase score after goal
func UpdateScore(playerScores: Array):
	scoren.text=str(playerScores[1])
	scores.text=str(playerScores[0])

#restartbutton event
func restartButtonPressed() -> void:
	print("Restart button pressed")
	if GameState.game_state!=GameState.GameStates.COUNTDOWN:
		emit_signal("restartButtonPressedSignal")
	
func endGame(player: int):
	countdownLabel.text="Player "+str(player)+" wins\nRestart game to play again"
	countdownLabel.show()
	
#start countdown before point start
func startCountdown():
	finalTextLabel.hide()
	countdownLabel.show()
	var numbers = [3, 2, 1]
	for n in numbers:
		countdownLabel.text = str(n)
		Sfx.PlaySound('321')
		await get_tree().create_timer(1.0).timeout

	countdownLabel.text = "GO!"
	Sfx.PlayGo()
	await get_tree().create_timer(0.5).timeout

	countdownLabel.hide()
	countdownFinished.emit()


func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Assets/Scene/Level/mainMenu.tscn")


func _on_music_icon_pressed() -> void:
	musicOff.emit()
	var bar: ColorRect=$UI/MusicIcon/ColorRect
	if Sfx.muted:
		bar.show()
	else:
		bar.hide()
	
