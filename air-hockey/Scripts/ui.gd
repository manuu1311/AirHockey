extends CanvasLayer


@onready var scoren= $UI/ScoreN
@onready var scores= $UI/ScoreS
signal restartButtonPressedSignal

func IncreaseScore(playerScores: Array):
	scoren.text=playerScores[1]
	scores.text=playerScores[0]




func restartButtonPressed() -> void:
	emit_signal("restartButtonPressedSignal")
