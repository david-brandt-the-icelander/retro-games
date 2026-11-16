extends Node
## Tiny procedural synth: every sound is generated at startup, so the
## project ships without any audio files.

const RATE := 44100

var _players := {}


func _ready() -> void:
	_add("eat", _chirp(620.0, 1240.0, 0.11, 0.32, 2))
	_add("bonus", _arp([660.0, 880.0, 1100.0, 1320.0], 0.065, 0.28))
	_add("start", _arp([440.0, 660.0, 880.0], 0.07, 0.24))
	_add("pause", _chirp(520.0, 390.0, 0.09, 0.2, 0))
	_add("die", _die_sound())
	_add("pop", _chirp(900.0, 500.0, 0.05, 0.12, 0))


func play(sound: String, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null:
		return
	p.pitch_scale = pitch
	p.play()


func _add(sound: String, stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.max_polyphony = 6
	add_child(p)
	_players[sound] = p


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _chirp(f0: float, f1: float, dur: float, vol: float, harmonics: int) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var x := float(i) / n
		var f := lerpf(f0, f1, x * x * (3.0 - 2.0 * x))
		ph += TAU * f / RATE
		var env := minf(1.0, i / (0.004 * RATE)) * pow(1.0 - x, 2.0)
		var v := sin(ph)
		if harmonics > 0:
			v += 0.3 * sin(ph * 2.0)
		if harmonics > 1:
			v += 0.12 * sin(ph * 3.0)
		s[i] = v * env * vol
	return _to_wav(s)


func _arp(notes: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var tail := 0.25
	var dur := notes.size() * note_dur + tail
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var last := notes.size() - 1
	for i in n:
		var t := float(i) / RATE
		var idx := mini(int(t / note_dur), last)
		var lt := t - idx * note_dur
		var f: float = notes[idx]
		ph += TAU * f / RATE
		var decay := 6.0 if idx == last else 14.0
		var env := minf(1.0, lt / 0.003) * exp(-lt * decay)
		var v := sin(ph) * 0.8 + 0.2 * sin(ph * 2.0)
		s[i] = v * env * vol
	return _to_wav(s)


func _die_sound() -> AudioStreamWAV:
	var dur := 0.75
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var rng := RandomNumberGenerator.new()
	for i in n:
		var x := float(i) / n
		var f := 260.0 * pow(45.0 / 260.0, x)
		ph += TAU * f / RATE
		var tone := sin(ph) * 0.55 + signf(sin(ph)) * 0.25
		var noise := rng.randf_range(-1.0, 1.0) * 0.35 * exp(-x * 6.0)
		var env := minf(1.0, i / (0.003 * RATE)) * pow(1.0 - x, 1.5)
		s[i] = (tone + noise) * env * 0.38
	return _to_wav(s)
