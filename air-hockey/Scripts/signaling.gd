extends Node

signal lobby_joined(lobby)
signal connected(id)
signal disconnected()
signal peer_connected(id)
signal peer_disconnected(id)
signal offer_received(id, offer)
signal answer_received(id, answer)
signal candidate_received(id, mid, index, sdp)
signal lobby_sealed()

var _ws := WebSocketPeer.new()
var _status := WebSocketPeer.STATE_CLOSED
var autojoin := true
var lobby := ""

func connect_to_url(url: String):
	close()
	_ws = WebSocketPeer.new()
	var tls_options = TLSOptions.client()
	_ws.connect_to_url(url, tls_options)
	_status = WebSocketPeer.STATE_CONNECTING

func close():
	_ws.close()
	_status = WebSocketPeer.STATE_CLOSED

func join_lobby(p_lobby: String):
	_ws.send_text("J: %s\n" % p_lobby)

func seal_lobby():
	_ws.send_text("S: \n")

func send_offer(id: int, offer: String):
	_ws.send_text("O: %d\n%s" % [id, offer])

func send_answer(id: int, answer: String):
	_ws.send_text("A: %d\n%s" % [id, answer])

func send_candidate(id: int, mid: String, index: int, sdp: String):
	# Pack the candidate data into the payload
	_ws.send_text("C: %d\n%s" % [id, JSON.stringify({"mid": mid, "index": index, "sdp": sdp})])


func _send_msg(type: String, id: int, data: String):
	_ws.send_text("%s: %d\n%s" % [type, id, data])


func _process(_delta):
	_ws.poll()
	var new_status = _ws.get_ready_state()

	if new_status != _status:
		print("WebSocket status changed: ", new_status)
		_status = new_status
		if _status == WebSocketPeer.STATE_OPEN:
			print("Connected to signaling server, joining lobby: ", lobby)
			if autojoin:
				join_lobby(lobby)
		elif _status == WebSocketPeer.STATE_CLOSED:
			var code = _ws.get_close_code()
			var reason = _ws.get_close_reason()
			print("WebSocket closed. Code: ", code, " Reason: '", reason, "'")
			if code <= 0:
				print("WARNING: Possible TLS or network failure - never reached server")
	
			emit_signal("disconnected")

	while _status == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count() > 0:
		var msg=_ws.get_packet().get_string_from_utf8()
		print("Received from signaling: ", msg)
		_parse_msg(msg)

func _parse_msg(pkt_str: String):
	# Server messages look like:  "I: 123\n"  "J: lobbyname\n"  "N: 456\n"  etc.
	var lines = pkt_str.strip_edges().split("\n", false)
	if lines.is_empty():
		return
	var header = lines[0]
	if header.length() < 3:
		return
	var cmd = header.substr(0, 1)      # "I", "J", "N", "D", "S", "O", "A", "C"
	var payload = header.substr(3).strip_edges()  # everything after "X: "
	var body = ""
	if lines.size() > 1:
		body = "\n".join(lines.slice(1))

	match cmd:
		"I":  # Server assigned us an ID
			emit_signal("connected", int(payload))
		"J":  # Lobby join confirmed
			emit_signal("lobby_joined", payload)
		"N":  # New peer in lobby
			emit_signal("peer_connected", int(payload))
		"D":  # Peer disconnected
			emit_signal("peer_disconnected", int(payload))
		"S":  # Lobby sealed
			emit_signal("lobby_sealed")
		"O":  # Offer relayed
			emit_signal("offer_received", int(payload), body)
		"A":  # Answer relayed
			emit_signal("answer_received", int(payload), body)
		"C":  # ICE candidate relayed
			var candidate = JSON.parse_string(body)
			if candidate == null:
				return
			emit_signal("candidate_received", int(payload),
				candidate["mid"], candidate["index"], candidate["sdp"])
				
