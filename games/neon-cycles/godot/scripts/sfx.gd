class_name Sfx
extends Node
## Neon Cycles' sound. Every sound is synthesised here into an AudioStreamWAV
## when the game starts, so the game still has no imported assets: an engine
## hum that follows the player's speed, a boost whoosh, turn blips, countdown
## beeps, crashes and the round jingles. Press M to mute.

const RATE := 22050
const MASTER_DB := -4.0

var muted := false

var _engine: AudioStreamPlayer
var _engine_target := -80.0
var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1982
	_streams["turn"] = _tone_stream(_sweep(780.0, 380.0, 0.07, 0.35, 0.0))
	_streams["beep"] = _tone_stream(_sweep(520.0, 520.0, 0.16, 0.4, 0.15))
	_streams["go"] = _tone_stream(_sweep(1040.0, 1040.0, 0.5, 0.4, 0.2))
	_streams["boost"] = _tone_stream(_whoosh(0.9))
	_streams["crash"] = _tone_stream(_explosion(1.4))
	_streams["win"] = _tone_stream(_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.13))
	_streams["match"] = _tone_stream(_arpeggio([392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5], 0.12))
	_streams["lose"] = _tone_stream(_sweep(420.0, 90.0, 0.9, 0.45, 0.35))
	_streams["draw"] = _tone_stream(_arpeggio([440.0, 440.0], 0.2))

	for i in 8:
		var v := AudioStreamPlayer.new()
		v.volume_db = MASTER_DB
		add_child(v)
		_voices.append(v)

	_engine = AudioStreamPlayer.new()
	var loop := _engine_loop()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = RATE
	_engine.stream = loop
	_engine.volume_db = -80.0
	add_child(_engine)
	_engine.play()


func _process(delta: float) -> void:
	var target := -80.0 if muted else _engine_target
	_engine.volume_db = move_toward(_engine.volume_db, target, 120.0 * delta)


func toggle_mute() -> bool:
	muted = not muted
	return muted


## Called every frame by the game: speed is the player's, or 0 when silent.
func set_engine(speed: float, boost_speed: float, base_speed: float, on: bool) -> void:
	if not on:
		_engine_target = -80.0
		return
	var k := clampf((speed - base_speed) / (boost_speed - base_speed), 0.0, 1.0)
	_engine.pitch_scale = lerpf(0.85, 1.55, clampf(speed / boost_speed, 0.0, 1.0)) + k * 0.1
	_engine_target = MASTER_DB - 14.0 + k * 4.0


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if muted or not _streams.has(sound):
		return
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	v.stream = _streams[sound]
	v.volume_db = MASTER_DB + volume_db
	v.pitch_scale = pitch
	v.play()


## A crash, quieter the further it is from the listener.
func play_crash(distance: float, own: bool) -> void:
	var fall := clampf(distance / 120.0, 0.0, 1.0)
	play("crash", (0.0 if own else -6.0) - fall * 22.0, 1.0 if own else _rng.randf_range(0.9, 1.1))


# --------------------------------------------------------------------------
# Synthesis
# --------------------------------------------------------------------------

func _tone_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## A square-ish tone gliding from f0 to f1, with a short attack and a decay.
func _sweep(f0: float, f1: float, secs: float, amp: float, vibrato: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t) * (1.0 + vibrato * 0.02 * sin(t * 40.0))
		phase += f / RATE
		var s := sin(phase * TAU) + 0.35 * sin(phase * TAU * 2.0) + 0.2 * sin(phase * TAU * 3.0)
		var env := minf(1.0, t * 40.0) * pow(1.0 - t, 1.6)
		out[i] = s * 0.6 * amp * env
	return out


func _arpeggio(notes: Array, step: float) -> PackedFloat32Array:
	var note_n := int((step * 1.8) * RATE)
	var total := int(step * RATE) * (notes.size() - 1) + note_n
	var out := PackedFloat32Array()
	out.resize(total)
	for k in notes.size():
		var start := int(step * RATE) * k
		var phase := 0.0
		for i in note_n:
			var t := float(i) / note_n
			phase += notes[k] / RATE
			var s := sin(phase * TAU) + 0.3 * sin(phase * TAU * 2.0) + 0.15 * sin(phase * TAU * 4.0)
			out[start + i] += s * 0.4 * minf(1.0, t * 60.0) * pow(1.0 - t, 1.8)
	return out


## Rising filtered noise: the boost kicking in.
func _whoosh(secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var a := lerpf(0.04, 0.5, t * t)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * a
		var env := sin(t * PI) * (0.4 + 0.6 * t)
		out[i] = lp * 1.6 * env
	return out


## A low boom and crackling noise that darkens as it fades.
func _explosion(secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var a := lerpf(0.9, 0.04, sqrt(t))
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * a
		phase += lerpf(150.0, 35.0, sqrt(t)) / RATE
		var boom := sin(phase * TAU) * pow(1.0 - t, 1.2)
		var env := minf(1.0, t * 200.0) * pow(1.0 - t, 2.0)
		out[i] = (lp * 1.2 * env + boom * 0.7) * 0.8
	return out


## One second, so every harmonic is a whole number of cycles and it loops cleanly.
func _engine_loop() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(RATE)
	for i in RATE:
		var t := float(i) / RATE
		var s := 0.0
		s += sin(TAU * 55.0 * t) * 0.5
		s += sin(TAU * 110.0 * t + 0.6 * sin(TAU * 4.0 * t)) * 0.35
		s += sin(TAU * 165.0 * t) * 0.18
		s += sin(TAU * 220.0 * t) * 0.12
		s += sin(TAU * 330.0 * t) * 0.07 * (0.6 + 0.4 * sin(TAU * 8.0 * t))
		out[i] = s * 0.55
	return _tone_stream(out)
