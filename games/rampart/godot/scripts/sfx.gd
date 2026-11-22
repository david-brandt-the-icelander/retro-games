extends Node
## Procedurally synthesised sound effects (autoload "Sfx"). No audio files needed.

const RATE := 22050

var streams: Dictionary = {}
var players: Array = []
var idx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 18:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["laser"] = _laser()
	streams["explosion"] = _boom(1.3, 0.35, 0.9)
	streams["small_boom"] = _boom(0.5, 0.5, 0.7)
	streams["hit"] = _ping(0.09, 1500.0, 0.6)
	streams["ricochet"] = _ping(0.12, 2600.0, 0.4)
	streams["enemy_shot"] = _sweep(0.2, 900.0, 260.0, 0.4)
	streams["pickup"] = _arp([660.0, 880.0, 1320.0], 0.07)
	streams["alarm"] = _alarm()
	streams["start"] = _sweep(0.8, 180.0, 1400.0, 0.5)
	streams["boss_open"] = _sweep(0.6, 90.0, 260.0, 0.6)
	streams["boss_hit"] = _ping(0.15, 420.0, 0.7)
	streams["launch"] = _whoosh(0.7)


func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _buf(dur: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(RATE * dur))
	return s


func _laser() -> AudioStreamWAV:
	var dur := 0.14
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		ph += lerpf(2000.0, 360.0, pow(k, 0.6)) / RATE
		var sq := 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		s[i] = (sq * 0.3 + sin(ph * TAU) * 0.7) * pow(1.0 - k, 2.0) * 0.5
	return _make(s)


func _boom(dur: float, cutoff: float, vol: float) -> AudioStreamWAV:
	var s := _buf(dur)
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		var white := randf() * 2.0 - 1.0
		var c := cutoff * (1.0 - k * 0.85)
		lp += (white - lp) * c
		lp2 += (lp - lp2) * c
		ph += lerpf(85.0, 32.0, k) / RATE
		var thump := sin(ph * TAU) * pow(1.0 - k, 3.0) * 0.8
		s[i] = clampf((lp2 * 2.4 * pow(1.0 - k, 1.6) + thump) * vol, -1.0, 1.0)
	return _make(s)


func _ping(dur: float, freq: float, vol: float) -> AudioStreamWAV:
	var s := _buf(dur)
	for i in s.size():
		var k := float(i) / s.size()
		var t := float(i) / RATE
		var v := sin(t * freq * TAU) * 0.6 + sin(t * freq * 2.76 * TAU) * 0.3 + (randf() * 2.0 - 1.0) * 0.25 * (1.0 - k)
		s[i] = v * pow(1.0 - k, 3.0) * vol
	return _make(s)


func _sweep(dur: float, f0: float, f1: float, vol: float) -> AudioStreamWAV:
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		ph += lerpf(f0, f1, k) / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		var env := minf(k * 20.0, 1.0) * pow(1.0 - k, 1.5)
		s[i] = (sin(ph * TAU) * 0.7 + saw * 0.3) * env * vol
	return _make(s)


func _arp(notes: Array, step: float) -> AudioStreamWAV:
	var s := _buf(step * notes.size() + 0.15)
	for i in s.size():
		var t := float(i) / RATE
		var n := mini(int(t / step), notes.size() - 1)
		var local := t - n * step
		var f: float = notes[n]
		var env := exp(-local * 14.0) if n < notes.size() - 1 else exp(-local * 6.0)
		s[i] = (sin(t * f * TAU) * 0.6 + sin(t * f * 2.0 * TAU) * 0.2) * env * 0.6
	return _make(s)


func _alarm() -> AudioStreamWAV:
	var s := _buf(0.32)
	for i in s.size():
		var t := float(i) / RATE
		var on := 1.0 if fmod(t, 0.16) < 0.11 else 0.0
		var sq := 1.0 if fmod(t * 880.0, 1.0) < 0.5 else -1.0
		s[i] = sq * on * 0.22
	return _make(s)


func _whoosh(dur: float) -> AudioStreamWAV:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		lp += ((randf() * 2.0 - 1.0) - lp) * lerpf(0.05, 0.4, k)
		s[i] = lp * sin(k * PI) * 1.6
	return _make(s)
