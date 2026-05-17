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
    if pkt_str.is_empty():
        return

    # Find the position of the first newline character
    var first_newline = pkt_str.find("\n")
    var header := ""
    var body := ""

    if first_newline == -1:
        # Message has no body (e.g., "J: room_name" or "S: ")
        header = pkt_str.strip_edges()
    else:
        # Split purely into Header and Body parts
        header = pkt_str.substr(0, first_newline).strip_edges()
        body = pkt_str.substr(first_newline + 1) # Keep formatting intact

    if header.length() < 3:
        return

    var cmd = header.substr(0, 1)                  # "I", "J", "N", "D", "S", "O", "A", "C"
    var payload = header.substr(3).strip_edges()  # Everything after the "X: "

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
            emit_signal("offer_received", int(payload), body.strip_edges())
        "A":  # Answer relayed
            emit_signal("answer_received", int(payload), body.strip_edges())
        "C":  # ICE candidate relayed
            var candidate = JSON.parse_string(body.strip_edges())
            if candidate == null:
                print("Error parsing ICE candidate JSON!")
                return
            emit_signal("candidate_received", int(payload),
                candidate["mid"], candidate["index"], candidate["sdp"])
                
