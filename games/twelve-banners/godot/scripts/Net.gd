extends Node
## Networking + lobby + turn orchestration (autoload "Net").
##
## The host is authoritative: clients send commands, the host resolves them
## into events and broadcasts them (in order) to everyone.  Single-player is
## simply hosting without opening a network port.

signal lobby_changed
signal game_started
signal connection_failed(reason: String)
signal disconnected
signal status(text: String)

const DEFAULT_PORT := 24565
## ENet needs UDP sockets, which a browser doesn't have: the web build plays against the computer only.
var CAN_HOST: bool = not OS.has_feature("web")

var peer: ENetMultiplayerPeer = null
var online := false
var is_host := true
var my_name := "Player"

## Lobby state (host-owned, mirrored to clients).
## humans: [{peer, name}]  ai_count: int  map_size: int
var lobby := {"humans": [], "ai_count": 3, "map_size": 1}

var game: Game = null
var local_pid := 0
var seq := 0
var _turn_running := false
var auto_end_delay := 0.25

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit("Could not connect to host."))
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ---------------------------------------------------------------- lobby

func host_offline(player_name: String) -> void:
	_close()
	online = false
	is_host = true
	my_name = player_name
	lobby = {"humans": [{"peer": 1, "name": player_name}], "ai_count": 3, "map_size": 1}
	lobby_changed.emit()

func host_online(player_name: String, port: int) -> Error:
	_close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Defs.MAX_PLAYERS)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = true
	my_name = player_name
	lobby = {"humans": [{"peer": 1, "name": player_name}], "ai_count": 2, "map_size": 1}
	lobby_changed.emit()
	return OK

func join(player_name: String, address: String, port: int) -> Error:
	_close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = false
	my_name = player_name
	status.emit("Connecting to %s:%d…" % [address, port])
	return OK

func _close() -> void:
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	game = null

func leave() -> void:
	_close()
	is_host = true

func total_players() -> int:
	return lobby.humans.size() + lobby.ai_count

func set_ai_count(n: int) -> void:
	if not is_host:
		return
	lobby.ai_count = clampi(n, 0, Defs.MAX_PLAYERS - lobby.humans.size())
	if total_players() < 2 and lobby.humans.size() == 1:
		lobby.ai_count = 1
	_push_lobby()

func set_map_size(i: int) -> void:
	if not is_host:
		return
	lobby.map_size = clampi(i, 0, Defs.MAP_SIZES.size() - 1)
	_push_lobby()

func _push_lobby() -> void:
	lobby_changed.emit()
	if online and is_host:
		_rpc_lobby.rpc(lobby)

func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	if game != null:
		# Game in progress: refuse.
		_rpc_refused.rpc_id(id, "Game already in progress.")
		return

func _on_connected() -> void:
	status.emit("Connected. Waiting for host…")
	_rpc_hello.rpc_id(1, my_name)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(player_name: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if game != null:
		_rpc_refused.rpc_id(id, "Game already in progress.")
		return
	if lobby.humans.size() >= Defs.MAX_PLAYERS:
		_rpc_refused.rpc_id(id, "Lobby is full (12 players).")
		return
	lobby.humans.append({"peer": id, "name": player_name.strip_edges().left(20)})
	if total_players() > Defs.MAX_PLAYERS:
		lobby.ai_count = Defs.MAX_PLAYERS - lobby.humans.size()
	_push_lobby()

@rpc("authority", "call_remote", "reliable")
func _rpc_refused(reason: String) -> void:
	connection_failed.emit(reason)
	_close()

@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(state: Dictionary) -> void:
	lobby = state
	lobby_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	if game == null:
		for i in lobby.humans.size():
			if lobby.humans[i].peer == id:
				lobby.humans.remove_at(i)
				break
		_push_lobby()
		return
	for p in game.players:
		if p.peer_id == id:
			_host_emit([{"t": "drop", "p": p.id}])
	_maybe_end_turn()

func _on_server_disconnected() -> void:
	_close()
	disconnected.emit()

# ---------------------------------------------------------------- start game

func start_game(seed_value: int = -1) -> void:
	if not is_host:
		return
	if seed_value < 0:
		seed_value = randi()
	var slots := []
	var order := range(Defs.CIVS.size())
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	for i in range(order.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var id := 0
	for hmn in lobby.humans:
		slots.append({"id": id, "name": hmn.name, "civ": order[id], "color": id, "peer": hmn.peer})
		id += 1
	for i in lobby.ai_count:
		var civ: int = order[id]
		slots.append({"id": id, "name": Defs.CIVS[civ].leader, "civ": civ, "color": id, "peer": 0})
		id += 1
	var size: Dictionary = Defs.MAP_SIZES[lobby.map_size]
	var map := MapGen.generate(size.w, size.h, seed_value, slots)
	map["seed"] = seed_value
	if online:
		_rpc_start.rpc(map)
	_begin(map)
	game.rng.seed = seed_value ^ 0x5eed
	_start_of_turn()
	call_deferred("_maybe_end_turn")

@rpc("authority", "call_remote", "reliable")
func _rpc_start(map: Dictionary) -> void:
	_begin(map)

func _begin(map: Dictionary) -> void:
	game = Game.new()
	game.name = "Game"
	game.setup_from_dict(map)
	seq = 0
	local_pid = -1
	var my_peer := multiplayer.get_unique_id() if online else 1
	for p in game.players:
		if p.peer_id == my_peer:
			local_pid = p.id
	if local_pid < 0:
		local_pid = 0
	game_started.emit()

# ---------------------------------------------------------------- commands / events

## Called by UI for the local player.
func send(cmd: Dictionary) -> void:
	if game == null:
		return
	if is_host:
		host_submit(local_pid, cmd)
	else:
		_rpc_command.rpc_id(1, cmd)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_command(cmd: Dictionary) -> void:
	if not is_host or game == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var pid := -1
	for p in game.players:
		if p.peer_id == sender:
			pid = p.id
	if pid < 0:
		return
	host_submit(pid, cmd)

func host_submit(pid: int, cmd: Dictionary) -> bool:
	var evs := game.resolve(pid, cmd)
	if evs.is_empty():
		return false
	_host_emit(evs)
	if cmd.get("t", "") == "ready":
		_maybe_end_turn()
	return true

func _host_emit(evs: Array) -> void:
	for ev in evs:
		seq += 1
		if online:
			_rpc_event.rpc(ev, seq)
		game.apply(ev)

@rpc("authority", "call_remote", "reliable")
func _rpc_event(ev: Dictionary, s: int) -> void:
	if game == null:
		return
	seq = s
	game.apply(ev)

# ---------------------------------------------------------------- turn flow (host)

var stop_at_turn := 1 << 30

func _maybe_end_turn() -> void:
	while true:
		if not is_host or game == null or game.finished or _turn_running:
			return
		if not game.humans_ready() or game.turn >= stop_at_turn:
			return
		_turn_running = true
		_host_emit(game.city_bombard_events())
		_host_emit([{"t": "new_turn"}])
		_start_of_turn()
		_turn_running = false
		# All-AI games (or everyone gone) keep rolling.
		if game == null or game.finished or not game.humans_ready():
			return
		if auto_end_delay > 0.0:
			await get_tree().create_timer(auto_end_delay).timeout

func _start_of_turn() -> void:
	if game == null or game.finished:
		return
	# Continue multi-turn moves for everyone.
	for u in game.units.values().duplicate():
		if game.units.has(u.id) and u.goto.x >= 0 and u.moves > 0:
			if not host_submit(u.owner, {"t": "move", "u": u.id, "to": u.goto}):
				_host_emit([{"t": "cancel", "u": u.id}])
	for p in game.players:
		if p.alive and p.is_ai() and not game.finished:
			AI.run_turn(game, p.id, func(cmd): return host_submit(p.id, cmd))
