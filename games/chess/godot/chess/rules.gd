class_name Chess
extends RefCounted
## The rules of chess: positions, legal moves, SAN and results. The server judges online games
## with chess.js; this is the same rules for the board in the game, tested against the standard
## perft counts (tests/test_rules.gd).
##
## Squares are 0..63: a1 = 0, h1 = 7, a8 = 56. A piece is its type (PAWN..KING) plus BLACK for
## black's pieces. A move is an int: from | to << 6 | promotion type << 12 | flags << 16.

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const BLACK := 8

const F_CAPTURE := 1
const F_EP := 2
const F_CASTLE := 4
const F_DOUBLE := 8

const FILES := "abcdefgh"
const LETTERS := ["", "", "N", "B", "R", "Q", "K"]
const KNIGHT_STEPS := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const KING_STEPS := [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]
const ROOK_DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]
const BISHOP_DIRS := [[1, 1], [1, -1], [-1, 1], [-1, -1]]


class Position:
	var board := PackedInt32Array()
	var white := true            ## white to move
	var castling := 15           ## 1 white king side, 2 white queen side, 4 black king side, 8 black queen side
	var ep := -1                 ## the square a pawn can capture en passant on, or -1
	var halfmove := 0
	var fullmove := 1

	func copy() -> Position:
		var p := Position.new()
		p.board = board.duplicate()
		p.white = white
		p.castling = castling
		p.ep = ep
		p.halfmove = halfmove
		p.fullmove = fullmove
		return p


static func start() -> Position:
	var p := Position.new()
	p.board.resize(64)
	var back := [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
	for f in 8:
		p.board[f] = back[f]
		p.board[8 + f] = PAWN
		p.board[48 + f] = PAWN | BLACK
		p.board[56 + f] = back[f] | BLACK
	return p


## A position from FEN (used by the tests).
static func from_fen(fen: String) -> Position:
	var p := Position.new()
	p.board.resize(64)
	var parts := fen.split(" ")
	var rank := 7
	var file := 0
	for c in parts[0]:
		if c == "/":
			rank -= 1
			file = 0
		elif c.is_valid_int():
			file += int(c)
		else:
			var t := "pnbrqk".find(c.to_lower()) + 1
			p.board[rank * 8 + file] = t | (BLACK if c == c.to_lower() else 0)
			file += 1
	p.white = parts[1] == "w"
	p.castling = 0
	for c in parts[2]:
		p.castling |= {"K": 1, "Q": 2, "k": 4, "q": 8}.get(c, 0)
	p.ep = -1 if parts[3] == "-" else square(parts[3])
	p.halfmove = int(parts[4]) if parts.size() > 4 else 0
	p.fullmove = int(parts[5]) if parts.size() > 5 else 1
	return p


static func square(name: String) -> int:
	return (int(name[1]) - 1) * 8 + FILES.find(name[0])


static func square_name(sq: int) -> String:
	return FILES[sq % 8] + str(sq / 8 + 1)


static func piece_type(piece: int) -> int:
	return piece & 7


static func is_black(piece: int) -> bool:
	return piece & BLACK != 0


static func move_from(m: int) -> int:
	return m & 63


static func move_to(m: int) -> int:
	return (m >> 6) & 63


static func move_promo(m: int) -> int:
	return (m >> 12) & 7


static func move_flags(m: int) -> int:
	return m >> 16


static func _mv(from: int, to: int, promo: int, flags: int) -> int:
	return from | (to << 6) | (promo << 12) | (flags << 16)


static func _on(f: int, r: int) -> bool:
	return f >= 0 and f < 8 and r >= 0 and r < 8


## Is `sq` attacked by the side `by_white`?
static func attacked(p: Position, sq: int, by_white: bool) -> bool:
	var f := sq % 8
	var r := sq / 8
	var mine := 0 if by_white else BLACK
	# Pawns
	var pr := r - 1 if by_white else r + 1
	for df in [-1, 1]:
		if _on(f + df, pr) and p.board[pr * 8 + f + df] == (PAWN | mine):
			return true
	for s in KNIGHT_STEPS:
		if _on(f + s[0], r + s[1]) and p.board[(r + s[1]) * 8 + f + s[0]] == (KNIGHT | mine):
			return true
	for s in KING_STEPS:
		if _on(f + s[0], r + s[1]) and p.board[(r + s[1]) * 8 + f + s[0]] == (KING | mine):
			return true
	for d in ROOK_DIRS:
		var x: int = f + d[0]
		var y: int = r + d[1]
		while _on(x, y):
			var q := p.board[y * 8 + x]
			if q != EMPTY:
				if q == (ROOK | mine) or q == (QUEEN | mine):
					return true
				break
			x += d[0]
			y += d[1]
	for d in BISHOP_DIRS:
		var x: int = f + d[0]
		var y: int = r + d[1]
		while _on(x, y):
			var q := p.board[y * 8 + x]
			if q != EMPTY:
				if q == (BISHOP | mine) or q == (QUEEN | mine):
					return true
				break
			x += d[0]
			y += d[1]
	return false


static func king_square(p: Position, white: bool) -> int:
	return p.board.find(KING | (0 if white else BLACK))


static func in_check(p: Position) -> bool:
	var k := king_square(p, p.white)
	return k >= 0 and attacked(p, k, not p.white)


static func _pseudo(p: Position) -> Array[int]:
	var out: Array[int] = []
	var me := 0 if p.white else BLACK
	for sq in 64:
		var piece := p.board[sq]
		if piece == EMPTY or (piece & BLACK) != me:
			continue
		var t := piece & 7
		var f := sq % 8
		var r := sq / 8
		match t:
			PAWN:
				var dir := 1 if p.white else -1
				var start_rank := 1 if p.white else 6
				var last_rank := 7 if p.white else 0
				var r1 := r + dir
				if _on(f, r1) and p.board[r1 * 8 + f] == EMPTY:
					_add_pawn(out, sq, r1 * 8 + f, 0, r1 == last_rank)
					if r == start_rank and p.board[(r + 2 * dir) * 8 + f] == EMPTY:
						out.append(_mv(sq, (r + 2 * dir) * 8 + f, 0, F_DOUBLE))
				for df in [-1, 1]:
					if not _on(f + df, r1):
						continue
					var to: int = r1 * 8 + f + df
					var q := p.board[to]
					if q != EMPTY and (q & BLACK) != me:
						_add_pawn(out, sq, to, F_CAPTURE, r1 == last_rank)
					elif to == p.ep:
						out.append(_mv(sq, to, 0, F_CAPTURE | F_EP))
			KNIGHT, KING:
				for s in (KNIGHT_STEPS if t == KNIGHT else KING_STEPS):
					var x: int = f + s[0]
					var y: int = r + s[1]
					if not _on(x, y):
						continue
					var q := p.board[y * 8 + x]
					if q == EMPTY:
						out.append(_mv(sq, y * 8 + x, 0, 0))
					elif (q & BLACK) != me:
						out.append(_mv(sq, y * 8 + x, 0, F_CAPTURE))
				if t == KING:
					_add_castles(p, out, sq)
			_:
				var dirs: Array = []
				if t != BISHOP:
					dirs.append_array(ROOK_DIRS)
				if t != ROOK:
					dirs.append_array(BISHOP_DIRS)
				for d in dirs:
					var x: int = f + d[0]
					var y: int = r + d[1]
					while _on(x, y):
						var q := p.board[y * 8 + x]
						if q == EMPTY:
							out.append(_mv(sq, y * 8 + x, 0, 0))
						else:
							if (q & BLACK) != me:
								out.append(_mv(sq, y * 8 + x, 0, F_CAPTURE))
							break
						x += d[0]
						y += d[1]
	return out


static func _add_pawn(out: Array[int], from: int, to: int, flags: int, promotes: bool) -> void:
	if promotes:
		for t in [QUEEN, ROOK, BISHOP, KNIGHT]:
			out.append(_mv(from, to, t, flags))
	else:
		out.append(_mv(from, to, 0, flags))


static func _add_castles(p: Position, out: Array[int], sq: int) -> void:
	var home := 4 if p.white else 60
	if sq != home or attacked(p, home, not p.white):
		return
	var k_right := 1 if p.white else 4
	var q_right := 2 if p.white else 8
	var b := p.board
	if p.castling & k_right and b[home + 1] == EMPTY and b[home + 2] == EMPTY \
			and b[home + 3] == (ROOK | (0 if p.white else BLACK)) \
			and not attacked(p, home + 1, not p.white) and not attacked(p, home + 2, not p.white):
		out.append(_mv(home, home + 2, 0, F_CASTLE))
	if p.castling & q_right and b[home - 1] == EMPTY and b[home - 2] == EMPTY and b[home - 3] == EMPTY \
			and b[home - 4] == (ROOK | (0 if p.white else BLACK)) \
			and not attacked(p, home - 1, not p.white) and not attacked(p, home - 2, not p.white):
		out.append(_mv(home, home - 2, 0, F_CASTLE))


## The position after a move (the move must come from legal_moves or _pseudo).
static func make(p: Position, m: int) -> Position:
	var n := p.copy()
	var from := move_from(m)
	var to := move_to(m)
	var flags := move_flags(m)
	var piece := n.board[from]
	var t := piece & 7
	n.board[to] = piece if move_promo(m) == 0 else (move_promo(m) | (piece & BLACK))
	n.board[from] = EMPTY
	if flags & F_EP:
		n.board[to + (-8 if p.white else 8)] = EMPTY
	if flags & F_CASTLE:
		if to > from:
			n.board[from + 1] = n.board[from + 3]
			n.board[from + 3] = EMPTY
		else:
			n.board[from - 1] = n.board[from - 4]
			n.board[from - 4] = EMPTY
	# Castling rights go when the king or a rook moves, or a rook is captured.
	for s in [from, to]:
		match s:
			4: n.castling &= ~3
			0: n.castling &= ~2
			7: n.castling &= ~1
			60: n.castling &= ~12
			56: n.castling &= ~8
			63: n.castling &= ~4
	n.ep = (from + to) / 2 if flags & F_DOUBLE else -1
	n.halfmove = 0 if (t == PAWN or flags & F_CAPTURE) else p.halfmove + 1
	if not p.white:
		n.fullmove += 1
	n.white = not p.white
	return n


static func legal_moves(p: Position) -> Array[int]:
	var out: Array[int] = []
	for m in _pseudo(p):
		var n := make(p, m)
		var k := king_square(n, p.white)
		if not attacked(n, k, n.white):
			out.append(m)
	return out


static func uci(m: int) -> String:
	var s := square_name(move_from(m)) + square_name(move_to(m))
	if move_promo(m):
		s += "nbrq"[move_promo(m) - 2]
	return s


## The legal move a UCI string names in a position, or -1.
static func parse_uci(p: Position, s: String) -> int:
	for m in legal_moves(p):
		if uci(m) == s:
			return m
	return -1


## The move in standard algebraic notation (needs the position before it).
static func san(p: Position, m: int) -> String:
	var from := move_from(m)
	var to := move_to(m)
	var t := p.board[from] & 7
	var s := ""
	if move_flags(m) & F_CASTLE:
		s = "O-O" if to > from else "O-O-O"
	else:
		if t == PAWN:
			if move_flags(m) & F_CAPTURE:
				s = FILES[from % 8]
		else:
			s = LETTERS[t]
			# Disambiguate between pieces of the same kind that can reach the same square.
			var same_file := false
			var same_rank := false
			var other := false
			for o in legal_moves(p):
				if move_to(o) == to and move_from(o) != from and (p.board[move_from(o)] & 7) == t:
					other = true
					if move_from(o) % 8 == from % 8:
						same_file = true
					if move_from(o) / 8 == from / 8:
						same_rank = true
			if other:
				if not same_file:
					s += FILES[from % 8]
				elif not same_rank:
					s += str(from / 8 + 1)
				else:
					s += square_name(from)
		if move_flags(m) & F_CAPTURE:
			s += "x"
		s += square_name(to)
		if move_promo(m):
			s += "=" + LETTERS[move_promo(m)]
	var n := make(p, m)
	if in_check(n):
		s += "#" if legal_moves(n).is_empty() else "+"
	return s


## What decides repetition: the pieces, who moves, castling, and en passant only when it can be taken.
static func repetition_key(p: Position) -> String:
	var ep := -1
	if p.ep >= 0:
		for m in legal_moves(p):
			if move_flags(m) & F_EP:
				ep = p.ep
				break
	return "%s|%s|%d|%d" % [p.board, p.white, p.castling, ep]


static func insufficient_material(p: Position) -> bool:
	var others := []
	for sq in 64:
		var t := p.board[sq] & 7
		if t != EMPTY and t != KING:
			others.append([t, sq])
	if others.is_empty():
		return true
	if others.size() == 1 and (others[0][0] == KNIGHT or others[0][0] == BISHOP):
		return true
	# Only bishops, all on squares of one colour.
	var colour := -1
	for o in others:
		if o[0] != BISHOP:
			return false
		var c: int = (o[1] % 8 + o[1] / 8) % 2
		if colour == -1:
			colour = c
		elif c != colour:
			return false
	return true


static func perft(p: Position, depth: int) -> int:
	if depth == 0:
		return 1
	var moves := legal_moves(p)
	if depth == 1:
		return moves.size()
	var n := 0
	for m in moves:
		n += perft(make(p, m), depth - 1)
	return n


## A game: the moves so far (UCI), with every position, the SAN of each move and the result the
## board decides. Online, the server's result (resignation, agreement) is set by the caller.
class Game:
	var moves: PackedStringArray = []
	var positions: Array[Position] = []
	var played: Array[int] = []       ## the moves as ints
	var sans: PackedStringArray = []
	var result := "*"
	var reason := ""

	func _init() -> void:
		positions.append(Chess.start())

	var current: Position:
		get: return positions[-1]

	## Plays a UCI move. False if it isn't legal.
	func play(u: String) -> bool:
		var m := Chess.parse_uci(current, u)
		if m < 0:
			return false
		sans.append(Chess.san(current, m))
		played.append(m)
		positions.append(Chess.make(current, m))
		moves.append(u)
		_judge()
		return true

	func _judge() -> void:
		var p := current
		var legal := Chess.legal_moves(p)
		if legal.is_empty():
			if Chess.in_check(p):
				result = "0-1" if p.white else "1-0"
				reason = "checkmate"
			else:
				result = "1/2-1/2"
				reason = "stalemate"
		elif Chess.insufficient_material(p):
			result = "1/2-1/2"
			reason = "material"
		elif _repeated() >= 3:
			result = "1/2-1/2"
			reason = "repetition"
		elif p.halfmove >= 100:
			result = "1/2-1/2"
			reason = "fifty"
		else:
			result = "*"
			reason = ""

	func _repeated() -> int:
		var key := Chess.repetition_key(current)
		var n := 0
		for p in positions:
			if Chess.repetition_key(p) == key:
				n += 1
		return n

	static func from_moves(list: PackedStringArray) -> Game:
		var g := Game.new()
		for u in list:
			if not g.play(u):
				break
		return g


## How a finished game ended, in words.
static func describe(result: String, reason: String, white := "White", black := "Black") -> String:
	if result == "*":
		return "In play"
	var winner := white if result == "1-0" else black
	var loser := black if result == "1-0" else white
	match reason:
		"checkmate": return "Checkmate. %s wins" % winner
		"resign": return "%s resigned. %s wins" % [loser, winner]
		"abandoned": return "%s left. %s wins" % [loser, winner]
		"stalemate": return "Stalemate. Drawn"
		"material": return "Insufficient material. Drawn"
		"repetition": return "Threefold repetition. Drawn"
		"fifty": return "Fifty-move rule. Drawn"
		"agreement": return "Draw agreed"
	return "Drawn" if result == "1/2-1/2" else "%s wins" % winner
