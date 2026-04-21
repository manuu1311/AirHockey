extends Sprite2D


@onready var goalNorth=$GoalLlines/GoalLineNorth
@onready var goalSouth=$GoalLlines/GoalLineSouth
signal goalScored(player:int)

func _ready() -> void:
	goalNorth.body_entered.connect(score.bind(0))
	goalSouth.body_entered.connect(score.bind(1))
	var size = texture.get_size() * global_scale
	print(size)
	
func score(_body, player:int):
	print('Goal scored by player '+str(player))
	goalScored.emit(player)
