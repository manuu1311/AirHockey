extends Node

@export var model_paths: String='res://Assets/'
var params: Array
#0-20: ar 4, 20-30: ar3, 35-/: ar=2
var paths: Array=['ppo.json']
var action_repeat=[2]

func _ready() -> void:
	for path in paths:
		var file = FileAccess.open(model_paths + path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if data != null:
				params.append(data)
			else:
				print("JSON parse error for: ", path)
		else:
			print("Failed to open file: ", path)

	
#random distribution function
func weighted_random_index(weights_dist: Array) -> int:
	var total := 0.0
	for w in weights_dist:
		total += w

	var r := randf() * total
	var cumulative := 0.0

	for i in range(weights_dist.size()):
		cumulative += weights_dist[i]
		if r < cumulative:
			return i

	return weights_dist.size() - 1  
