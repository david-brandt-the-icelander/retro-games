extends Node
## Sessions, the lobby, and one message layer over three transports (autoload "Net").
##
##   relay  in the browser: the games hub's match relay, a WebSocket at /games/multiplayer/match/ID
##          (the same relay Rally, Shatterbelt and Hivestorm use). Matches start on icelander.net's
##          multiplayer page, which opens the game with ?match=ID. Peer id = relay slot + 1.
##   enet   on the desktop: host or join by IP address. Peer id = Godot's multiplayer id.
##   solo   practice on your own, with nothing on the network.
##
## Every message names a node path, a method and its arguments. The host (the lowest id still
## present) is authoritative: methods that change shared state (ev_*, the lobby's _sync_lobby, _start,
## _lobby, _late_joiner) are only accepted from it, and requests (rq_*) are only acted on by it.

signal lobby_changed
signal status(msg: String)
signal game_started(config: Dictionary)
signal back_to_lobby
signal disconnected
signal peer_left(id: int, was_host: bool)

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 15
const RELAY_PATH := "/games/multiplayer/match/"
const PING_SECONDS := 20.0

const HOST_ONLY := ["_sync_lobby", "_start", "_lobby", "_late_joiner"]
const ALLOWED := ["_register", "_rq_team", "_rq_spectator", "_sync_lobby", "_start", "_lobby", "_late_joiner", "net_state"]

var players := {}   # peer_id -> {name, team, spectator, color}
var settings := {"map": "embassy", "mode": "lms"}
var my_name := "Agent"
var in_game := false

var transport := ""   # "", "relay", "enet", "solo"
var my_id := 0
var host_id := 0
var peers: Array[int] = []     # everyone present, me included
var sender := 0                # who sent the message being handled (my_id for local calls)
var match_id := ""
var relay_names := {}          # peer id -> name the relay gave them

var _ws: WebSocketPeer
var _ws_state := -1
var _welcomed := false
var _ping_t := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_enet_peer_connected)
	multiplayer.peer_disconnected.connect(_on_enet_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_enet_connected)
	multiplayer.connection_failed.connect(func(): status.emit("Connection failed."); _reset())
	multiplayer.server_disconnected.connect(func(): _lost("The host closed the session."))


func is_online() -> bool:
	return transport != ""


func is_host() -> bool:
	return my_id != 0 and my_id == host_id


# ================================================================== sessions

func host(port: int, player_name: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		status.emit("Could not host on port %d (%s)." % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	transport = "enet"
	my_name = player_name
	my_id = 1
	host_id = 1
	peers = [1]
	players.clear()
	_add_player(1, player_name)
	status.emit("Hosting on port %d. Waiting for agents…" % port)
	lobby_changed.emit()
	return OK


func join(address: String, port: int, player_name: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		status.emit("Could not connect (%s)." % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	transport = "enet"
	my_name = player_name
	status.emit("Connecting to %s:%d…" % [address, port])
	return OK


func solo(player_name: String) -> void:
	transport = "solo"
	my_name = player_name
	my_id = 1
	host_id = 1
	peers = [1]
	players.clear()
	_add_player(1, player_name)
	lobby_changed.emit()


func join_match(id: String, origin: String) -> void:
	## Connects to the hub's relay for a match made on the multiplayer page.
	var url := origin.replace("https://", "wss://").replace("http://", "ws://") + RELAY_PATH + id
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		status.emit("The match can't be reached.")
		return
	transport = "relay"
	match_id = id
	_welcomed = false
	_ws_state = -1
	status.emit("Joining the match…")


func leave() -> void:
	_reset()
	status.emit("Left the session.")


func _reset() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _ws:
		_ws.close(1000, "bye")
		_ws = null
	transport = ""
	my_id = 0
	host_id = 0
	peers = []
	players.clear()
	relay_names.clear()
	in_game = false
	lobby_changed.emit()


func _lost(msg: String) -> void:
	var was_in_game := in_game
	_reset()
	status.emit(msg)
	if was_in_game:
		disconnected.emit()


# ================================================================== message layer

func call_all(node: Node, method: String, args: Array = []) -> void:
	## Everyone, this peer included.
	_dispatch(my_id, node.get_path(), method, args)
	_send(0, node.get_path(), method, args, true)


func call_others(node: Node, method: String, args: Array = [], reliable := true) -> void:
	_send(0, node.get_path(), method, args, reliable)


func call_host(node: Node, method: String, args: Array = []) -> void:
	call_peer(host_id, node, method, args)


func call_peer(peer: int, node: Node, method: String, args: Array = []) -> void:
	if peer == my_id:
		_dispatch(my_id, node.get_path(), method, args)
	elif peers.has(peer):
		_send(peer, node.get_path(), method, args, true)


func _send(to: int, path: NodePath, method: String, args: Array, reliable: bool) -> void:
	if transport == "solo" or transport == "":
		return
	var packet := var_to_bytes([to, str(path), method, args])
	if transport == "enet":
		if to == 0:
			(_pkt if reliable else _pkt_fast).rpc(packet)
		else:
			_pkt.rpc_id(to, packet)
	elif transport == "relay" and _welcomed:
		var msg := {"t": "g", "d": Marshalls.raw_to_base64(packet)}
		if to != 0:
			msg.to = to - 1
		_ws.send_text(JSON.stringify(msg))


@rpc("any_peer", "reliable")
func _pkt(packet: PackedByteArray) -> void:
	_receive(multiplayer.get_remote_sender_id(), packet)


@rpc("any_peer", "unreliable_ordered")
func _pkt_fast(packet: PackedByteArray) -> void:
	_receive(multiplayer.get_remote_sender_id(), packet)


func _receive(from: int, packet: PackedByteArray) -> void:
	if from == my_id or packet.size() > 65536:
		return
	var msg = bytes_to_var(packet)
	if not (msg is Array) or msg.size() != 4 or not (msg[1] is String) or not (msg[2] is String) or not (msg[3] is Array):
		return
	var to := int(msg[0])
	if to != 0 and to != my_id:
		return
	_dispatch(from, NodePath(msg[1]), msg[2], msg[3])


func _dispatch(from: int, path: NodePath, method: String, args: Array) -> void:
	var host_only := method.begins_with("ev_") or HOST_ONLY.has(method)
	if not (host_only or method.begins_with("rq_") or ALLOWED.has(method)):
		return
	if host_only and from != host_id:
		return
	var node := get_node_or_null(path)
	if node == null or not node.has_method(method):
		return
	var prev := sender
	sender = from
	node.callv(method, args)
	sender = prev


# ================================================================== relay transport

func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			_relay_message(_ws.get_packet().get_string_from_utf8())
		_ping_t -= delta
		if _ping_t <= 0.0:
			_ping_t = PING_SECONDS
			_ws.send_text("ping")
	elif state == WebSocketPeer.STATE_CLOSED and _ws_state != WebSocketPeer.STATE_CLOSED:
		_ws_state = state
		var why := "The connection to the match was lost." if _welcomed else \
			"The match can't be reached. Are you signed in? Matches start from the multiplayer page."
		_ws = null
		_lost(why)
		return
	_ws_state = state


const REFUSALS := {
	"missing": "This match has ended, or never started. Start a new one from the multiplayer page.",
	"not-yours": "This match was started for other players. Start your own from the multiplayer page.",
}


func _relay_message(text: String) -> void:
	if text == "pong":
		return
	var msg = JSON.parse_string(text)
	if not (msg is Dictionary) or not msg.has("t"):
		return
	if not _welcomed:
		if msg.t == "welcome":
			_welcomed = true
			my_id = int(msg.you) + 1
			var names: Array = msg.get("names", [])
			for i in names.size():
				relay_names[i + 1] = str(names[i]).substr(0, 16)
			peers.clear()
			for s in msg.get("peers", []):
				peers.append(int(s) + 1)
			if not peers.has(my_id):
				peers.append(my_id)
			my_name = relay_names.get(my_id, "Agent")
			_elect_host()
			status.emit("")
			if is_host():
				players.clear()
				for p in peers:
					_add_player(p, relay_names.get(p, "Agent %d" % p))
				_broadcast()
			lobby_changed.emit()
		else:
			_lost(REFUSALS.get(str(msg.get("reason", "")), "The match can't be reached."))
		return
	match str(msg.t):
		"join":
			var id := int(msg.slot) + 1
			if not peers.has(id):
				peers.append(id)
			if is_host():
				_add_player(id, relay_names.get(id, "Agent %d" % id))
				if in_game:
					players[id].spectator = true
					call_peer(id, self, "_late_joiner")
				_broadcast()
		"leave":
			_peer_gone(int(msg.slot) + 1)
		"g":
			if msg.has("from") and msg.has("d"):
				_receive(int(msg.from) + 1, Marshalls.base64_to_raw(str(msg.d)))


func _elect_host() -> void:
	host_id = peers.min() if not peers.is_empty() else 0


func _peer_gone(id: int) -> void:
	if not peers.has(id):
		return
	peers.erase(id)
	var was_host := id == host_id
	_elect_host()
	players.erase(id)
	peer_left.emit(id, was_host)
	if is_host() and not in_game:
		_broadcast()
	lobby_changed.emit()


# ================================================================== enet transport

func _on_enet_connected() -> void:
	my_id = multiplayer.get_unique_id()
	host_id = 1
	peers = [1, my_id]
	call_host(self, "_register", [my_name])


func _on_enet_peer_connected(id: int) -> void:
	if not peers.has(id):
		peers.append(id)


func _on_enet_peer_disconnected(id: int) -> void:
	_peer_gone(id)


# ================================================================== lobby

func _register(player_name: String) -> void:
	if not is_host():
		return
	var id := sender
	if not peers.has(id):
		peers.append(id)
	_add_player(id, player_name)
	if in_game:
		players[id].spectator = true
		call_peer(id, self, "_late_joiner")
	_broadcast()


func _late_joiner() -> void:
	status.emit("A match is in progress — you'll join the next round.")


func _add_player(id: int, player_name: String) -> void:
	if players.has(id):
		return
	var used := []
	var team_counts := [0, 0]
	for p in players.values():
		used.append(p.color)
		if not p.spectator:
			team_counts[p.team] += 1
	var color := 0
	while used.has(color):
		color += 1
	var clean := player_name.strip_edges().substr(0, 16)
	if clean.is_empty():
		clean = "Agent %d" % (players.size() + 1)
	players[id] = {
		"name": clean, "team": 0 if team_counts[0] <= team_counts[1] else 1,
		"spectator": false, "color": color % Maps.PLAYER_COLORS.size(),
	}


func _broadcast() -> void:
	call_all(self, "_sync_lobby", [players, settings])


func _sync_lobby(p: Dictionary, s: Dictionary) -> void:
	players = p
	settings = s
	lobby_changed.emit()


func set_team(team: int) -> void:
	call_host(self, "_rq_team", [team])


func set_spectator(on: bool) -> void:
	call_host(self, "_rq_spectator", [on])


func set_settings(map_id: String, mode: String) -> void:
	if is_host() and Maps.DEFS.has(map_id) and (mode == "lms" or mode == "teams"):
		settings = {"map": map_id, "mode": mode}
		_broadcast()


func _rq_team(team: int) -> void:
	if is_host() and players.has(sender):
		players[sender].team = clampi(team, 0, 1)
		_broadcast()


func _rq_spectator(on: bool) -> void:
	if is_host() and players.has(sender):
		players[sender].spectator = on
		_broadcast()


func active_players() -> Array:
	var out := []
	for id in players:
		if not players[id].spectator:
			out.append(id)
	return out


func can_start() -> String:
	## "" if the match can start, else why not.
	var n := active_players().size()
	var def: Dictionary = Maps.DEFS[settings.map]
	if n == 0:
		return "Nobody is playing — everyone is spectating."
	if n > def.max_players:
		return "%s holds at most %d agents (%d ready)." % [def.name, def.max_players, n]
	return ""


func start_game() -> void:
	if not is_host():
		return
	var reason := can_start()
	if reason != "":
		status.emit(reason)
		return
	call_all(self, "_start", [{
		"seed": randi(),
		"map": settings.map,
		"mode": settings.mode,
		"players": players.duplicate(true),
		"duration": 600.0,
	}])


func _start(config: Dictionary) -> void:
	in_game = true
	game_started.emit(config)


func return_to_lobby() -> void:
	if is_host():
		call_all(self, "_lobby")
		_broadcast()


func _lobby() -> void:
	in_game = false
	back_to_lobby.emit()


func local_return_to_lobby() -> void:
	## After the host has gone: everyone left goes back to the briefing room on their own.
	in_game = false
	back_to_lobby.emit()
	if is_host():
		for id in players.keys():
			if not peers.has(id):
				players.erase(id)
		_broadcast()
