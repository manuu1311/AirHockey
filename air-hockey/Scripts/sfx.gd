extends AudioStreamPlayer

var fx:Dictionary[String,AudioStream]
var pitch: Dictionary[String,float]
var db: Dictionary[String,float]
var muted: bool=false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	volume_db=0
	pitch={
		'321':1,
		'gol':1.0,
		'taken':0.8,
		'win':1.2,
		'lose':0.9
	}
	db={
		'321':-10,
		'gol':0,
		'taken':0,
		'win':0,
		'lose':0
	}
	fx={
		'321':preload("res://Sounds/321.wav"),
		'gol':preload("res://Sounds/goalscored.wav"),
		'taken':preload("res://Sounds/goaltaken.mp3"),
		'win':preload('res://Sounds/winmatch.mp3'),
		'lose':preload('res://Sounds/losematch.mp3')
	}

func PlaySound(sound: String)->void:
	pitch_scale=pitch[sound]
	volume_db=db[sound]
	if muted:
		return
	stream=fx[sound]
	play()
	
func PlayGo()->void:
	
	if muted:
		return
	stream=fx['321']
	pitch_scale=2
	volume_db=db['321']
	play()
