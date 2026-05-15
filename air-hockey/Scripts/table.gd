extends Sprite2D


@onready var goalNorth=$GoalLlines/GoalLineNorth
@onready var goalSouth=$GoalLlines/GoalLineSouth
@onready var goalSouth2=$GoalLlines/GoalLineSouth2
@onready var goalSouth3=$GoalLlines/GoalLineSouth3
@onready var goalSouth4=$GoalLlines/GoalLineSouth4
@onready var goalNorth2=$GoalLlines/GoalLineNorth2
@onready var goalNorth3=$GoalLlines/GoalLineNorth3
@onready var goalNorth4=$GoalLlines/GoalLineNorth4
signal goalScored(player:int)
var playing=false

func _ready() -> void:
	playing=true
	goalNorth.body_entered.connect(score.bind(0))
	goalSouth.body_entered.connect(score.bind(1))
	if GameState.training and false:
		print('connecting additional goal lines')
		goalNorth2.body_entered.connect(score.bind(0))
		goalNorth3.body_entered.connect(score.bind(0))
		goalNorth4.body_entered.connect(score.bind(0))
		goalSouth2.body_entered.connect(score.bind(1))
		goalSouth3.body_entered.connect(score.bind(1))
		goalSouth4.body_entered.connect(score.bind(1))
	
func score(_body, player:int):
	if playing:
		print('Goal scored by player '+str(player))
		goalScored.emit(player)
		playing=false
func reset():
	playing=true
	
func puckout():
	goalScored.emit(1)
