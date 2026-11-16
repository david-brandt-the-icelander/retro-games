extends Node
## Synthesised sound effects (no audio assets needed). Autoloaded as `Sfx`.

const RATE := 22050

var streams := {}
var pool: Array = []
var thrust_player: AudioStreamPlayer
var thrust_target := -60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	streams["laser"] = _wav(_sweep(0.13, 1900.0, 320.0, "sq", 0.16, 1.6, 0.0))
	streams["explode"] = _wav(_boom(0.65, 0.5))
	streams["death"] = _wav(_sweep(0.9, 700.0, 45.0, "saw", 0.22, 1.1, 0.35))
	streams["pickup"] = _wav(_arp([660.0, 880.0, 1320.0], 0.055, "tri", 0.3))
	streams["gem"] = _wav(_arp([1046.0, 1318.0, 1568.0, 2093.0], 0.05, "tri", 0.28))
	streams["clunk"] = _wav(_sweep(0.24, 190.0, 55.0, "sin", 0.6, 2.4, 0.25))
	streams["fuel"] = _wav(_sweep(0.32, 260.0, 980.0, "tri", 0.28, 1.0, 0.05))
	streams["ready"] = _wav(_arp([523.0, 659.0, 784.0, 1046.0, 1318.0], 0.08, "sq", 0.12))
	streams["start"] = _wav(_arp([392.0, 523.0, 659.0, 784.0], 0.09, "tri", 0.3))
	streams["oneup"] = _wav(_arp([784.0, 988.0, 1175.0, 1568.0, 1976.0], 0.06, "sq", 0.12))
	streams["launch"] = _wav(_rumble(3.2))
	thrust_player = AudioStreamPlayer.new()
	thrust_player.stream = _wav(_noise_loop(0.75), true)
	thrust_player.volume_db = -60.0
	add_child(thrust_player)
	thrust_player.play()


func _process(delta: float) -> void:
	thrust_player.volume_db = move_toward(thrust_player.volume_db, thrust_target, 240.0 * delta)


func set_thrust(on: bool) -> void:
	thrust_target = -11.0 if on else -60.0


func play(sname: String, vol_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if not streams.has(sname):
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[sname]
			p.volume_db = vol_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func _wav(s: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


func _osc(wave: String, ph: float) -> float:
	var f := fmod(ph, 1.0)
	match wave:
		"sq":
			return 1.0 if f < 0.5 else -1.0
		"saw":
			return f * 2.0 - 1.0
		"tri":
			return absf(f * 4.0 - 2.0) - 1.0
	return sin(ph * TAU)


func _sweep(dur: float, f0: float, f1: float, wave: String, vol: float, decay: float, noise: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var x := float(i) / float(n)
		var f := f0 * pow(f1 / f0, x)
		ph += f / RATE
		var v := _osc(wave, ph)
		if noise > 0.0:
			v = lerpf(v, randf() * 2.0 - 1.0, noise)
		var env := pow(1.0 - x, decay) * minf(1.0, float(i) / 60.0)
		out[i] = v * vol * env
	return out


func _arp(notes: Array, each: float, wave: String, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in notes.size():
		var n := int(each * RATE)
		var ph := 0.0
		for i in n:
			var x := float(i) / float(n)
			ph += notes[k] / RATE
			var tail := 1.0 if k < notes.size() - 1 else (1.0 - x)
			out.append(_osc(wave, ph) * vol * minf(1.0, float(i) / 40.0) * (1.0 - x * 0.4) * tail)
	return out


func _boom(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var x := float(i) / float(n)
		var k := lerpf(0.45, 0.03, x)
		lp += (randf() * 2.0 - 1.0 - lp) * k
		ph += lerpf(90.0, 35.0, x) / RATE
		var v := lp * 1.6 + sin(ph * TAU) * 0.6 * (1.0 - x)
		out[i] = v * vol * pow(1.0 - x, 1.6)
	return out


func _rumble(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var x := float(i) / float(n)
		lp += (randf() * 2.0 - 1.0 - lp) * lerpf(0.05, 0.2, x)
		ph += lerpf(40.0, 110.0, x) / RATE
		var env := minf(1.0, x * 5.0) * pow(1.0 - x, 0.7)
		out[i] = (lp * 2.2 + sin(ph * TAU) * 0.35) * 0.5 * env
	return out


func _noise_loop(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf() * 2.0 - 1.0 - lp) * 0.16
		out[i] = lp * 1.4
	# cross-fade the ends to hide the loop seam
	var fade := 600
	for i in fade:
		var a := float(i) / float(fade)
		out[i] = out[i] * a + out[n - fade + i] * (1.0 - a)
	return out.slice(0, n - fade)
