extends Node

signal signal_lobby_created(code: String)
signal signal_lobby_joined
signal signal_game_ready
signal signal_client_disconnected

const WEB_SOCKET_SERVER_URL = "wss://airhockey-h1ul.onrender.com"

var ws_peer: WebSocketPeer
var web_rtc_peer: WebRTCMultiplayerPeer

var my_id:         int    = -1
var is_host:       bool   = false
var current_lobby: String = ""

var _pending_join_code: String = ""
var _join_sent:         bool   = false

var ICE_SERVERS = {
	"iceServers": [
		#{"urls": ["stun:stun.l.google.com:19302"]},
		{
			"urls": [
				"turn:openrelay.metered.ca:80",
				"turn:openrelay.metered.ca:443",
                "turn:openrelay.metered.ca:443?transport=tcp"
			],
			"username": "openrelayproject",
			"credential": "openrelayproject"
		}
	]
}

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_process(false)
	tree_exited.connect(_ws_close_connection)


func _process(_delta: float) -> void:
	ws_peer.poll()

	match ws_peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return

		WebSocketPeer.STATE_OPEN:
			if not _join_sent:
				_join_sent = true
				_ws_send_text("J: %s\n" % _pending_join_code)
			while ws_peer.get_available_packet_count():
				_ws_parse_packet()

		WebSocketPeer.STATE_CLOSING:
			pass

		WebSocketPeer.STATE_CLOSED:
			var code   = ws_peer.get_close_code()
			var reason = ws_peer.get_close_reason()
			print("WS closed. Code: ", code, " Reason: '", reason, "'")
			if code <= 0:
				print("WARNING: Possible TLS or network failure – never reached server")
			signal_client_disconnected.emit()
			set_process(false)


# ── Public API ─────────────────────────────────────────────────────────────────

func lobby_host() -> void:
	is_host            = true
	_pending_join_code = ""
	_join_sent         = false
	_connect_to_server()

func lobby_join(code: String) -> void:
	is_host            = false
	_pending_join_code = code.strip_edges()
	_join_sent         = false
	_connect_to_server()

func disconnect_from_server() -> void:
	_ws_close_connection()
	if web_rtc_peer:
		web_rtc_peer.close()
		web_rtc_peer = null
	my_id         = -1
	current_lobby = ""


# ── WebSocket helpers ──────────────────────────────────────────────────────────

func _connect_to_server() -> void:
	ws_peer = WebSocketPeer.new()
	# Web export: browser handles TLS natively; desktop needs explicit TLSOptions
	if OS.has_feature("web"):
		ws_peer.connect_to_url(WEB_SOCKET_SERVER_URL)
	else:
		ws_peer.connect_to_url(WEB_SOCKET_SERVER_URL, TLSOptions.client())
	set_process(true)

func _ws_send_text(text: String) -> void:
	if ws_peer and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.send_text(text)

func _ws_close_connection(code: int = 1000, reason: String = "Disconnecting") -> void:
	if ws_peer and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.close(code, reason)


# ── Packet parsing ─────────────────────────────────────────────────────────────

func _ws_parse_packet() -> void:
	var raw = ws_peer.get_packet().get_string_from_utf8()
	print("Received from signaling: ", raw)

	if raw.is_empty():
		return

	var first_newline = raw.find("\n")
	var header: String
	var body: String

	if first_newline == -1:
		header = raw.strip_edges()
	else:
		header = raw.substr(0, first_newline).strip_edges()
		body   = raw.substr(first_newline + 1)

	if header.length() < 3:
		return

	var cmd     = header.substr(0, 1)
	var payload = header.substr(3).strip_edges()

	match cmd:
		"I":  # Server assigned us an ID
			my_id = int(payload)
			print("[Net] Assigned ID: %d (host=%s)" % [my_id, str(my_id == 1)])
			_network_create_multiplayer_peer()

		"J":  # Lobby created / joined confirmed
			current_lobby = payload
			print("[Net] Lobby: ", current_lobby)
			if is_host:
				signal_lobby_created.emit(current_lobby)
			else:
				signal_lobby_joined.emit()

		"N":  # New peer arrived
			var peer_id = int(payload)
			print("[Net] New peer: ", peer_id)
			_network_create_new_peer_connection(peer_id)

		"D":  # Peer left
			print("[Net] Peer disconnected: ", int(payload))

		"S":  # Lobby sealed
			print("[Net] Lobby sealed")

		"O":  # Incoming offer
			var from_id = int(payload)
			if web_rtc_peer and web_rtc_peer.has_peer(from_id):
				web_rtc_peer.get_peer(from_id).connection.set_remote_description("offer", body.strip_edges())

		"A":  # Incoming answer
			var from_id = int(payload)
			if web_rtc_peer and web_rtc_peer.has_peer(from_id):
				web_rtc_peer.get_peer(from_id).connection.set_remote_description("answer", body.strip_edges())

		"C":  # Incoming ICE candidate – body is JSON
			var from_id   = int(payload)
			var candidate = JSON.parse_string(body.strip_edges())
			if candidate == null:
				print("[Net] Error parsing ICE candidate JSON!")
				return
			if web_rtc_peer and web_rtc_peer.has_peer(from_id):
				web_rtc_peer.get_peer(from_id).connection.add_ice_candidate(
					candidate["mid"], candidate["index"], candidate["sdp"]
				)


# ── WebRTC ─────────────────────────────────────────────────────────────────────

func _network_create_multiplayer_peer() -> void:
	web_rtc_peer = WebRTCMultiplayerPeer.new()
	web_rtc_peer.create_mesh(my_id)
	multiplayer.multiplayer_peer = web_rtc_peer
	multiplayer.peer_connected.connect(_on_rtc_peer_connected)
	multiplayer.peer_disconnected.connect(_on_rtc_peer_disconnected)

func _network_create_new_peer_connection(peer_id: int) -> void:
	if peer_id == my_id:
		return
	var conn := WebRTCPeerConnection.new()
	conn.initialize(ICE_SERVERS)
	conn.session_description_created.connect(_on_offer_created.bind(peer_id))
	conn.ice_candidate_created.connect(_on_ice_candidate_created.bind(peer_id))
	web_rtc_peer.add_peer(conn, peer_id)
	if my_id < peer_id:
		await get_tree().process_frame
		conn.create_offer()

func _on_offer_created(type: String, sdp: String, peer_id: int) -> void:
	if not web_rtc_peer.has_peer(peer_id):
		return
	web_rtc_peer.get_peer(peer_id).connection.set_local_description(type, sdp)
	var cmd = "O" if type == "offer" else "A"
	_ws_send_text("%s: %d\n%s" % [cmd, peer_id, sdp])

func _on_ice_candidate_created(mid: String, index: int, sdp: String, peer_id: int) -> void:
	# JSON body so the payload survives the server relay intact
	print("[Net] ICE candidate created for peer %d: %s" % [peer_id, mid])
	_ws_send_text("C: %d\n%s" % [peer_id, JSON.stringify({"mid": mid, "index": index, "sdp": sdp})])

func _on_rtc_peer_connected(id: int) -> void:
	print("[Net] WebRTC connected to peer %d" % id)
	signal_game_ready.emit()
	if is_host:
		_call_start_game_deferred.call_deferred()

func _on_rtc_peer_disconnected(id: int) -> void:
	print("[Net] WebRTC peer %d disconnected" % id)


# ── Game start (mirrors Lobby.gd exactly) ─────────────────────────────────────

func _call_start_game_deferred() -> void:
	print("Host sending start_game RPC...")
	await get_tree().create_timer(1.5).timeout
	start_game.rpc()

func _switch_to_game() -> void:
	print("Switching scene to mainGame...")
	get_tree().change_scene_to_file("res://Assets/Scene/Level/mainGame.tscn")

@rpc("any_peer", "call_local", "reliable")
func start_game() -> void:
	print("start_game RPC received")
	GameState.isMultiplayer = true
	_switch_to_game()
