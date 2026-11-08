extends Node
## Sounds, synthesised at start-up: a wooden tock for moves, a heavier knock for captures, soft
## chimes for messages and results. No sound files.

const RATE := 44100
var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_streams.move = _make(0.16, func(t: float) -> float:
		return _tock(t, 190.0, 34.0) * 0.9)
	_streams.capture = _make(0.3, func(t: float) -> float:
		return _tock(t, 150.0, 22.0) + _tock(t - 0.07, 120.0, 26.0) * 0.8)
	_streams.select = _make(0.06, func(t: float) -> float:
		return sin(TAU * 1450.0 * t) * exp(-t * 90.0) * 0.18)
	_streams.illegal = _make(0.2, func(t: float) -> float:
		return sin(TAU * 95.0 * t) * exp(-t * 18.0) * 0.4)
	_streams.notify = _make(0.6, func(t: float) -> float:
		return _bell(t, 659.3) + _bell(t - 0.12, 987.8))
	_streams.chat = _make(0.25, func(t: float) -> float:
		return _bell(t, 1174.7) * 0.6)
	_streams.win = _make(1.4, func(t: float) -> float:
		return _bell(t, 523.3) + _bell(t - 0.13, 659.3) + _bell(t - 0.26, 784.0) + _bell(t - 0.39, 1046.5) * 1.2)
	_streams.lose = _make(1.3, func(t: float) -> float:
		return _bell(t, 392.0) + _bell(t - 0.2, 311.1) + _bell(t - 0.4, 261.6))
	_streams.draw = _make(1.0, func(t: float) -> float:
		return _bell(t, 440.0) + _bell(t - 0.18, 554.4) * 0.8)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _tock(t: float, freq: float, decay: float) -> float:
	if t < 0.0:
		return 0.0
	var body := sin(TAU * freq * t + 3.0 * exp(-t * 60.0)) * exp(-t * decay)
	var click := (randf() * 2.0 - 1.0) * exp(-t * 400.0) * 0.6
	return (body + click) * 0.5


func _bell(t: float, freq: float) -> float:
	if t < 0.0:
		return 0.0
	var env := (1.0 - exp(-t * 300.0)) * exp(-t * 4.5)
	return (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t) * exp(-t * 6.0)) * env * 0.14


func _make(seconds: float, fn: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var fade := clampf((seconds - t) / 0.02, 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(fn.call(t) * fade, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func play(name: String) -> void:
	if muted or not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.play()
			return
	_players[0].stream = _streams[name]
	_players[0].play()
