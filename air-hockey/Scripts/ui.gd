extends Control


@onready var scoren= $ScoreN
@onready var scores= %ScoreS
signal restart

func IncreaseScore(playerScores: Array):
	scoren.text=playerScores[1]
	scores.text=playerScores[0]


func restartButtonPressed() -> void:
	emit_signal("restart")
