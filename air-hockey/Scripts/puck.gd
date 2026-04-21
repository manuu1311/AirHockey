extends RigidBody2D

var startingPos: Vector2
var should_reset=false

var maxspeed=2000

func _ready() -> void:
	startingPos=position
#reset the position
func reset():
	should_reset=true
	show()
	set_deferred("freeze", false)
	sleeping = false
#hide the puck after goal scored
func disappear():
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	hide()
	set_deferred("freeze", true)
	
func _integrate_forces(state):
	if should_reset:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		state.transform.origin = get_parent().to_global(startingPos)
		show()
		set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		should_reset = false
	
func _physics_process(_delta):
	if linear_velocity.length() > maxspeed:
		linear_velocity = linear_velocity.limit_length(maxspeed)
		
