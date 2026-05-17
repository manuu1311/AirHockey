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
@export var blend_threshold: float = 40.0       # px — below this, skip pos correction
@export var pos_correction_strength: float = 0.25 # [0..1] per frame blend
var maxspeed := 2000

# Constants for field setup
const MIDDLE_LINE_Y: float = 450.0

#player1: north, player2: south
var PLAYER_1_ID: int = 0 
var PLAYER_2_ID: int = 0 


func _ready() -> void:
    startingPos = position
    can_sleep = false
    var client_id:=0
    if WebRtcManager.is_host:
        client_id = multiplayer.get_peers()[0]
    else:
        client_id = multiplayer.get_unique_id()
    PLAYER_1_ID=client_id
    PLAYER_2_ID=1


func reset():
    should_reset = true
    show()
    sleeping = false
    # Reset authority back to server/host on reset
    if GameState.isMultiplayer:
        set_multiplayer_authority(PLAYER_1_ID)


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
    # Non-authorities smoothly dead-reckon towards the authority's puck position
    if not is_multiplayer_authority() and _should_sync:
        # --- Dead reckoning ---
        var age_sec := (Time.get_ticks_msec() - _packet_received_at_ms) / 1000.0
        var predicted_pos := _remote_pos + _remote_vel * age_sec

        var err := (state.transform.origin - predicted_pos).length()

        if err > snap_threshold:
            state.transform.origin = predicted_pos
        elif err > blend_threshold:
            state.transform.origin = lerp(
                state.transform.origin,
                predicted_pos,
                clamp(pos_correction_strength, 0.0, 1.0)
            )

        state.linear_velocity = _remote_vel
        state.angular_velocity = _remote_ang_vel
        _should_sync = false

    # Only the authority processes physics alterations, boundaries, and manual forces
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
    if not GameState.isMultiplayer:
        return

    if is_multiplayer_authority():
        # 1. Broad-cast current state to the non-authority player
        sync_puck.rpc(global_position, linear_velocity, angular_velocity)
        
        # 2. Evaluate if authority needs to be handed over
        _check_authority_handoff()


func _check_authority_handoff() -> void:
    var current_auth = get_multiplayer_authority()
    
    # Assuming Player 1 handles Y < 450 (Top) and Player 2 handles Y > 450 (Bottom)
    if global_position.y > MIDDLE_LINE_Y and current_auth != PLAYER_2_ID:
        # Pass authority to Player 2
        rpc("switch_authority", PLAYER_2_ID)
        set_multiplayer_authority(PLAYER_2_ID)
        
    elif global_position.y <= MIDDLE_LINE_Y and current_auth != PLAYER_1_ID:
        # Pass authority to Player 1
        rpc("switch_authority", PLAYER_1_ID)
        set_multiplayer_authority(PLAYER_1_ID)


@rpc("authority", "call_local", "reliable")
func switch_authority(new_auth_id: int) -> void:
    set_multiplayer_authority(new_auth_id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func sync_puck(pos: Vector2, vel: Vector2, ang_vel: float) -> void:
    # Safety check: only accept sync data if it actually comes from the true authority
    if multiplayer.get_remote_sender_id() == get_multiplayer_authority():
        _remote_pos = pos
        _remote_vel = vel
        _remote_ang_vel = ang_vel
        _packet_received_at_ms = Time.get_ticks_msec() 
        _should_sync = true
