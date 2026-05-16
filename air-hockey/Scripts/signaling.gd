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
	_ws.connect_to_url(url)
	_status = WebSocketPeer.STATE_CONNECTING

func close():
	_ws.close()
	_status = WebSocketPeer.STATE_CLOSED

func join_lobby(p_lobby: String):
	_ws.send_text("J: %s\n" % p_lobby)

func seal_lobby():
	_ws.send_text("S: \n")

func send_candidate(id, mid, index, sdp):
	_send_msg("C", id, "\n%s\n%d\n%s" % [mid, index, sdp])

func send_offer(id, offer):
	_send_msg("O", id, offer)

func send_answer(id, answer):
	_send_msg("A", id, answer)

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
			print("WebSocket closed. Code: ", _ws.get_close_code(), " Reason: ", _ws.get_close_reason())
			emit_signal("disconnected")

	while _status == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count() > 0:
		var msg=_ws.get_packet().get_string_from_utf8()
		print("Received from signaling: ", msg)
		_parse_msg(msg)

func _parse_msg(pkt_str: String):
	var req := pkt_str.split("\n", true, 1)
	if req.size() != 2:
		return
	var type := req[0]
	if type.length() < 3:
		return
	if type.begins_with("J: "):
		emit_signal("lobby_joined", type.substr(3))
		return
	elif type.begins_with("S: "):
		emit_signal("lobby_sealed")
		return
	var src_str := type.substr(3)
	if not src_str.is_valid_int():
		return
	var src_id := int(src_str)
	if type.begins_with("I: "):
		emit_signal("connected", src_id)
	elif type.begins_with("N: "):
		emit_signal("peer_connected", src_id)
	elif type.begins_with("D: "):
		emit_signal("peer_disconnected", src_id)
	elif type.begins_with("O: "):
		emit_signal("offer_received", src_id, req[1])
	elif type.begins_with("A: "):
		emit_signal("answer_received", src_id, req[1])
	elif type.begins_with("C: "):
		var candidate := req[1].split("\n", false)
		if candidate.size() != 3 or not candidate[1].is_valid_int():
			return
		emit_signal("candidate_received", src_id, candidate[0], int(candidate[1]), candidate[2])
