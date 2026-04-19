extends RigidBody2D

var startingPos: Vector2
var should_reset=false

func _ready() -> void:
	startingPos=position
func reset():
	should_reset=true
	
func _integrate_forces(state):
	if should_reset:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		state.transform.origin = get_parent().to_global(startingPos)
		should_reset = false
	
