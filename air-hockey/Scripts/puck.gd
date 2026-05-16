extends RigidBody2D

var startingPos: Vector2
var should_reset=false
var should_apply_vel=false
var player_apply_vel=0
@export var initial_vel:int=75

var _should_sync := false
var _remote_pos := Vector2.ZERO
var _remote_vel := Vector2.ZERO
var _remote_ang_vel := 0.0

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
	
func _physics_process(_delta):
	if GameState.isMultiplayer and is_multiplayer_authority():
		# host broadcasts every frame
		sync_puck.rpc(global_position, linear_velocity, angular_velocity)

func _integrate_forces(state):
	if _should_sync:
		state.transform.origin = _remote_pos
		state.linear_velocity = _remote_vel
		state.angular_velocity = _remote_ang_vel
		_should_sync = false
		
	
	if not GameState.isMultiplayer or is_multiplayer_authority():
		if should_reset:
			state.linear_velocity = Vector2.ZERO
			state.angular_velocity = 0
			if GameState.training:
				var offset = Vector2(
					randf_range(-300, 300), 
					randf_range(-150, 150)  
				)
				state.transform.origin = get_parent().to_global(startingPos+offset)
			else:
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
	
	

@rpc("authority", "call_remote", "unreliable")
func sync_puck(pos: Vector2, vel: Vector2, ang_vel: float):
	var diff : Vector2=pos-Vector2(400,450)
	_remote_pos = Vector2(400,450)-diff
	_remote_vel = Vector2(-vel.x, -vel.y)
	_remote_ang_vel = ang_vel
	_should_sync = true
		
