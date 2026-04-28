extends RigidBody2D

var startingPos: Vector2
var should_reset=false
var should_apply_vel=false
var player_apply_vel=0
@export var initial_vel:int=75

var maxspeed=2000

func _ready() -> void:
	startingPos=position
	can_sleep = false
#reset the position
func reset():
	should_reset=true
	show()
	sleeping = false
#apply initial velocity
func apply_initial_force(player:int):
	call_deferred("_apply_force_deferred", player)
func _apply_force_deferred(player: int) -> void:
	should_apply_vel = true
	player_apply_vel = player
#hide the puck after goal scored
func disappear():
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	hide()
func _integrate_forces(state):
	if should_reset:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		state.transform.origin = get_parent().to_global(startingPos)
		show()
		#set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		should_reset = false
	if state.linear_velocity.length() > maxspeed:
		state.linear_velocity = state.linear_velocity.limit_length(maxspeed)
	if should_apply_vel:
		state.sleeping = false
		state.linear_velocity = Vector2(0, player_apply_vel * initial_vel)
		should_apply_vel=false
	
func _physics_process(_delta):
	pass
		
