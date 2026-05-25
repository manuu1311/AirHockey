extends AudioStreamPlayer

var fx:Dictionary[String,AudioStream]
var pitch: Array[float]
var muted: bool=false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	volume_db=0
	pitch=[1,1.2,0.8,1.2,0.9]
	fx={
		'321':preload("res://Sounds/321.wav"),
		'gol':preload("res://Sounds/goalscored.wav"),
		'taken':preload("res://Sounds/goaltaken.mp3"),
		'win':preload('res://Sounds/winmatch.mp3'),
		'lose':preload('res://Sounds/losematch.mp3')
	}

func PlaySound(sound: String)->void:
	if muted:
		return
	pitch_scale=1
	stream=fx[sound]
	play()
	
func PlayGo()->void:
	if muted:
		return
	stream=fx['321']
	pitch_scale=2
	play()
