extends Node

signal game_ready()  # emitted when both players are connected and ready

const ICE_SERVERS = [
    {"urls": ["stun:stun.l.google.com:19302"]},
    {"urls": ["stun:stun1.l.google.com:19302"]},
    {"urls": ["stun:stun2.l.google.com:19302"]},
    {"urls": ["stun:stun3.l.google.com:19302"]},
    {"urls": ["stun:stun4.l.google.com:19302"]},
    # Add a free TURN server (if you can't set up your own)
    {"urls": ["turn:openrelay.metered.ca:80"], "username": "openrelayproject", "credential": "openrelayproject"}
]

var _rtc := WebRTCMultiplayerPeer.new()
var _peers := {}   # id -> WebRTCPeerConnection
var _my_id := 0
var _is_host := false
var _pending_client := false

func setup_host():
    _is_host = true
    _rtc.create_server()
    multiplayer.multiplayer_peer = _rtc
    multiplayer.peer_connected.connect(_on_rtc_peer_connected)
    _connect_signaling()

func setup_client():
    _is_host = false
    _pending_client = true
    _connect_signaling()

func _connect_signaling():
    if not Signaling.connected.is_connected(_on_connected):
        Signaling.connected.connect(_on_connected)
    if not Signaling.peer_connected.is_connected(_on_peer_connected):
        Signaling.peer_connected.connect(_on_peer_connected)
    if not Signaling.peer_disconnected.is_connected(_on_peer_disconnected):
        Signaling.peer_disconnected.connect(_on_peer_disconnected)
    if not Signaling.offer_received.is_connected(_on_offer_received):
        Signaling.offer_received.connect(_on_offer_received)
    if not Signaling.answer_received.is_connected(_on_answer_received):
        Signaling.answer_received.connect(_on_answer_received)
    if not Signaling.candidate_received.is_connected(_on_candidate_received):
        Signaling.candidate_received.connect(_on_candidate_received)

func _create_peer(id: int) -> WebRTCPeerConnection:
    var peer := WebRTCPeerConnection.new()
    peer.initialize({"iceServers": ICE_SERVERS})
    peer.session_description_created.connect(_on_sdp_created.bind(id))
    peer.ice_candidate_created.connect(_on_ice_candidate.bind(id))
    _rtc.add_peer(peer, id)
    _peers[id] = peer
    return peer

func _on_connected(_id: int):
    _my_id = 2
    print("My signaling ID: ", _my_id)
    if _pending_client:
        _pending_client = false
        _rtc.create_client(_my_id)
        multiplayer.multiplayer_peer = _rtc
        multiplayer.peer_connected.connect(_on_rtc_peer_connected)

func _on_rtc_peer_connected(id: int):
    print("RTC data channel open with peer: ", id)
    if _is_host:
        Signaling.seal_lobby()
    emit_signal("game_ready")

func _on_peer_connected(id: int):
    print("Peer connected to signaling: ", id)
    if _is_host:
        # Host initiates the offer
        var peer = _create_peer(id)
        peer.create_offer()

func _on_peer_disconnected(id: int):
    if _peers.has(id):
        _rtc.remove_peer(id)
        _peers.erase(id)

func _on_offer_received(id: int, offer: String):
    if not _peers.has(id):
        _create_peer(id)
    _peers[id].set_remote_description("offer", offer)

func _on_answer_received(id: int, answer: String):
    if _peers.has(id):
        _peers[id].set_remote_description("answer", answer)

func _on_candidate_received(id: int, mid: String, index: int, sdp: String):
    if _peers.has(id):
        _peers[id].add_ice_candidate(mid, index, sdp)

func _on_sdp_created(type: String, sdp: String, id: int):
    _peers[id].set_local_description(type, sdp)
    if type == "offer":
        Signaling.send_offer(id, sdp)
    else:
        Signaling.send_answer(id, sdp)

func _on_ice_candidate(mid: String, index: int, sdp: String, id: int):
    Signaling.send_candidate(id, mid, index, sdp)
    

func leave():
    for id in _peers:
        _rtc.remove_peer(id)
    _peers.clear()
    _rtc = WebRTCMultiplayerPeer.new()
    multiplayer.multiplayer_peer = null
    _is_host = false
    _my_id = 0
    # disconnect signaling signals to avoid stale connections
    if Signaling.connected.is_connected(_on_connected):
        Signaling.connected.disconnect(_on_connected)
    if Signaling.peer_connected.is_connected(_on_peer_connected):
        Signaling.peer_connected.disconnect(_on_peer_connected)
    if Signaling.peer_disconnected.is_connected(_on_peer_disconnected):
        Signaling.peer_disconnected.disconnect(_on_peer_disconnected)
    if Signaling.offer_received.is_connected(_on_offer_received):
        Signaling.offer_received.disconnect(_on_offer_received)
    if Signaling.answer_received.is_connected(_on_answer_received):
        Signaling.answer_received.disconnect(_on_answer_received)
    if Signaling.candidate_received.is_connected(_on_candidate_received):
        Signaling.candidate_received.disconnect(_on_candidate_received)

func _process(_delta):
    if multiplayer.multiplayer_peer != null:
        _rtc.poll()
