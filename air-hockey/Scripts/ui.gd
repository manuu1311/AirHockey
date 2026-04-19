extends CanvasLayer


@onready var scoren= $UI/ScoreN
@onready var scores= $UI/ScoreS
@onready var countdownLabel= $UI/Countdown
@onready var finalTextLabel= $UI/FinalText
signal restartButtonPressedSignal
signal countdownFinished

func _ready() -> void:
	countdownLabel.hide()
	finalTextLabel.hide()
	
#increase score after goal
func IncreaseScore(playerScores: Array):
	scoren.text=str(playerScores[1])
	scores.text=str(playerScores[0])

#restartbutton event
func restartButtonPressed() -> void:
	print("Restart button pressed")
	emit_signal("restartButtonPressedSignal")
	
func endGame(player: int):
	countdownLabel.add_theme_font_size_override("font_size", 9)
	countdownLabel.text="Player "+str(player)+" wins\nPress Restart Button to restart the game"
	countdownLabel.show()
	
#start countdown before point start
func startCountdown():
	finalTextLabel.hide()
	countdownLabel.show()
	var numbers = [3, 2, 1]
	for n in numbers:
		countdownLabel.text = str(n)
		await get_tree().create_timer(1.0).timeout

	countdownLabel.text = "GO!"
	await get_tree().create_timer(0.5).timeout

	countdownLabel.hide()
	countdownFinished.emit()
