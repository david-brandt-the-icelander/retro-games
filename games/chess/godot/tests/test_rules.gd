extends SceneTree
## Run with: godot --headless --path godot -s tests/test_rules.gd
## Checks move generation against the standard perft counts, and SAN, results and repetition.

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var start := Chess.start()
	check(Chess.perft(start, 1) == 20, "perft start 1 = 20")
	check(Chess.perft(start, 2) == 400, "perft start 2 = 400")
	check(Chess.perft(start, 3) == 8902, "perft start 3 = 8902")
	var kiwi := Chess.from_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	check(Chess.perft(kiwi, 1) == 48, "perft kiwipete 1 = 48")
	check(Chess.perft(kiwi, 2) == 2039, "perft kiwipete 2 = 2039")
	var p3 := Chess.from_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
	check(Chess.perft(p3, 3) == 2812, "perft position 3, 3 = 2812")
	var p4 := Chess.from_fen("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1")
	check(Chess.perft(p4, 2) == 264, "perft position 4, 2 = 264")
	var p5 := Chess.from_fen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8")
	check(Chess.perft(p5, 2) == 1486, "perft position 5, 2 = 1486")

	var g := Chess.Game.from_moves(PackedStringArray(["f2f3", "e7e5", "g2g4", "d8h4"]))
	check(g.result == "0-1" and g.reason == "checkmate", "fool's mate")
	check(g.sans == PackedStringArray(["f3", "e5", "g4", "Qh4#"]), "SAN of fool's mate: %s" % [g.sans])
	var promo := Chess.Game.from_moves(PackedStringArray(["a2a4", "b7b5", "a4b5", "a7a6", "b5a6", "c8b7", "a6b7", "h7h6", "b7a8q"]))
	check(promo.sans[-1] == "bxa8=Q", "promotion SAN: %s" % promo.sans[-1])
	var castle := Chess.Game.from_moves(PackedStringArray(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "e1g1"]))
	check(castle.sans[-1] == "O-O" and castle.current.board[5] == Chess.ROOK, "castling moves the rook")
	var rep := Chess.Game.from_moves(PackedStringArray(["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"]))
	check(rep.result == "1/2-1/2" and rep.reason == "repetition", "threefold repetition")
	var knights := Chess.Game.from_moves(PackedStringArray(["g1f3", "g8f6", "b1c3", "b8c6", "c3e4", "c6e5", "e4g5"]))
	check(knights.sans[-1] == "Neg5", "disambiguation by file: %s" % knights.sans[-1])
	check(Chess.parse_uci(Chess.start(), "e2e5") == -1, "illegal move is refused")
	check(Chess.insufficient_material(Chess.from_fen("8/8/4k3/8/8/2B5/4K3/8 w - - 0 1")), "K+B v K is a draw")
	check(not Chess.insufficient_material(Chess.from_fen("8/8/4k3/8/8/2R5/4K3/8 w - - 0 1")), "K+R v K is not")

	print("%d failures, %d ms" % [failures, Time.get_ticks_msec() - t0])
	quit(1 if failures else 0)
