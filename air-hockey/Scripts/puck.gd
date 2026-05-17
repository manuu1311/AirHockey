extends RigidBody2D

var startingPos: Vector2
var should_reset := false
var should_apply_vel := false
var player_apply_vel := 0
@export var initial_vel: int = 75

# Network sync
var _should_sync := false
var _remote_pos := Vector2.ZERO
var _remote_vel := Vector2.ZERO
var _remote_ang_vel := 0.0
var _packet_received_at_ms: int = 0  

@export var snap_threshold: float = 250.0      
@export var blend_threshold: float = 40.0        # px — below this, skip pos correction
@export var pos_correction_strength: float = 0.25 # [0..1] per frame blend
var maxspeed := 2000


func _ready() -> void:
	startingPos = position
	can_sleep = false
	print('host: ', WebRtcManager._is_host, ' puckpos: ', global_position)


func reset():
	should_reset = true
	show()
	sleeping = false


func apply_initial_force(player: int):
	call_deferred("_apply_force_deferred", player)

func _apply_force_deferred(player: int) -> void:
	should_apply_vel = true
	player_apply_vel = player


func disappear():
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	hide()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _should_sync:
		# --- Dead reckoning ---
		# Compensate for the time between packet arrival and this physics step.
		var age_sec := (Time.get_ticks_msec() - _packet_received_at_ms) / 1000.0
		var predicted_pos := _remote_pos + _remote_vel * age_sec

		var err := (state.transform.origin - predicted_pos).length()

		if err > snap_threshold:
			# Wildly out of sync — hard snap
			state.transform.origin = predicted_pos
		elif err > blend_threshold:
			# Noticeable error — smoothly correct position
			state.transform.origin = lerp(
				state.transform.origin,
				predicted_pos,
				clamp(pos_correction_strength, 0.0, 1.0)
			)
		# else: within tolerance — leave position alone, velocity will converge it

		# *** Apply velocity DIRECTLY — never lerp velocity. ***
		state.linear_velocity = _remote_vel
		state.angular_velocity = _remote_ang_vel
		_should_sync = false

	if not GameState.isMultiplayer or is_multiplayer_authority():
		if should_reset:
			state.linear_velocity = Vector2.ZERO
			state.angular_velocity = 0.0
			if GameState.training:
				var offset := Vector2(randf_range(-300, 300), randf_range(-150, 150))
				state.transform.origin = get_parent().to_global(startingPos + offset)
			else:
				state.transform.origin = get_parent().to_global(startingPos)
			show()
			should_reset = false

		if state.linear_velocity.length() > maxspeed:
			state.linear_velocity = state.linear_velocity.limit_length(maxspeed)

		if should_apply_vel:
			state.sleeping = false
			state.linear_velocity = Vector2(0, player_apply_vel * initial_vel)
			should_apply_vel = false


func _physics_process(_delta: float) -> void:
	if GameState.isMultiplayer and is_multiplayer_authority():
		sync_puck.rpc(global_position, linear_velocity, angular_velocity)


@rpc("authority", "call_remote", "unreliable_ordered")
func sync_puck(pos: Vector2, vel: Vector2, ang_vel: float) -> void:
	_remote_pos = pos
	_remote_vel = vel
	_remote_ang_vel = ang_vel
	_packet_received_at_ms = Time.get_ticks_msec() 
	_should_sync = true
