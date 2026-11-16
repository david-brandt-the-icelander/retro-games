extends SceneTree
## Run with: godot --headless --path godot -s tests/test_net.gd
## The message layer (scripts/net.gd): only the host may change shared state, only listed methods
## can be called from the network, and a message for someone else is ignored.

var failures := 0
var calls: Array = []


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


class Target extends Node:
	var log: Array
	func ev_thing(x: int) -> void: log.append(["ev_thing", x])
	func rq_thing(x: int) -> void: log.append(["rq_thing", x])
	func net_state(x: int) -> void: log.append(["net_state", x])
	func secret(x: int) -> void: log.append(["secret", x])


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var net = load("res://scripts/net.gd").new()
	net.name = "NetUnderTest"
	root.add_child(net)
	var t := Target.new()
	t.name = "Target"
	t.log = calls
	root.add_child(t)
	net.my_id = 2
	net.host_id = 1
	net.peers.assign([1, 2, 3])
	var pkt := func(to: int, method: String, x: int) -> PackedByteArray:
		return var_to_bytes([to, str(t.get_path()), method, [x]])

	net._receive(1, pkt.call(0, "ev_thing", 1))
	check(calls.back() == ["ev_thing", 1], "the host's event is applied")
	calls.clear()
	net._receive(3, pkt.call(0, "ev_thing", 2))
	check(calls.is_empty(), "an event from someone who isn't the host is ignored")
	net._receive(1, pkt.call(0, "secret", 3))
	check(calls.is_empty(), "a method that isn't listed can't be called")
	net._receive(1, pkt.call(3, "ev_thing", 4))
	check(calls.is_empty(), "a message for another peer is ignored")
	net._receive(1, pkt.call(2, "ev_thing", 5))
	check(calls.back() == ["ev_thing", 5], "a message for this peer is applied")
	net._receive(3, pkt.call(0, "net_state", 6))
	check(calls.back() == ["net_state", 6] and net.sender == 0, "anyone may send their own state; sender is reset after")
	calls.clear()
	net._receive(3, PackedByteArray([1, 2, 3]))
	net._receive(3, var_to_bytes("nonsense"))
	check(calls.is_empty(), "garbage is ignored")
	net._receive(2, pkt.call(0, "net_state", 7))
	check(calls.is_empty(), "an echo of this peer's own message is ignored")
	# Host election: the lowest id still present
	net._peer_gone(1)
	check(net.host_id == 2 and net.is_host(), "when the host leaves, the lowest id left hosts")
	if failures == 0:
		print("test_net: all passed")
	quit(1 if failures > 0 else 0)
