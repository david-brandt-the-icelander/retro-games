extends Node
## Every sound in the game, synthesised in code at start-up (no audio files):
## a two-tone phone ring, a car horn, and "bla-bla" speech syllables pitched per speaker.

const RATE := 22050
const VOWELS := [[730.0, 1090.0], [530.0, 1840.0], [270.0, 2290.0], [570.0, 840.0], [300.0, 870.0]]  # a e i o u

var _syllables: Array = []
var _ring: AudioStreamWAV
var _horn: AudioStreamWAV
var _voices: Array = []
var _next := 0
var _ring_player: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for v in VOWELS:
		_syllables.append(_make_syllable(v[0], v[1]))
	_ring = _make_ring()
	_horn = _make_horn()
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_voices.append(p)
	_ring_player = AudioStreamPlayer.new()
	_ring_player.volume_db = -4.0
	add_child(_ring_player)

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
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

## One 75 ms vowel: a buzzy voice at 180 Hz shaped by two formant peaks.
func _make_syllable(f1: float, f2: float) -> AudioStreamWAV:
	var n := int(RATE * 0.075)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := 180.0
	var gains := []
	for h in range(1, 16):
		var f := f0 * h
		gains.append((exp(-pow((f - f1) / 160.0, 2)) + 0.7 * exp(-pow((f - f2) / 260.0, 2)) + 0.08) / sqrt(h))
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for h in range(1, 16):
			s += sin(TAU * f0 * h * t) * gains[h - 1]
		var env := minf(1.0, t / 0.006) * clampf((0.075 - t) / 0.03, 0.0, 1.0)
		out[i] = s * env * 0.35
	return _wav(out)

## Old desk-phone ring: 440+480 Hz bell trilled at 20 Hz, two rings.
func _make_ring() -> AudioStreamWAV:
	var n := int(RATE * 3.2)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var cycle := fmod(t, 1.6)
		if cycle > 1.0:
			continue
		var trill := 1.0 if fmod(t * 20.0, 1.0) < 0.5 else 0.25
		var s := sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t)
		out[i] = s * 0.3 * trill * minf(1.0, cycle / 0.01) * minf(1.0, (1.0 - cycle) / 0.02)
	return _wav(out)

func _make_horn() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for f in [349.0, 440.0]:      # two horns a third apart, square-ish
			s += signf(sin(TAU * f * t)) * 0.5 + sin(TAU * f * 2.0 * t) * 0.2
		out[i] = s * 0.18 * minf(1.0, t / 0.01) * minf(1.0, (0.45 - t) / 0.04)
	return _wav(out)

## Each speaker gets a fixed pitch from their name; Jim is low and cheerful.
func voice_pitch(speaker: String) -> float:
	var k := speaker.to_upper()
	if k == "JIM" or k.begins_with("JIM "):
		return 0.78
	var h := absi(k.hash())
	return 0.72 + float(h % 1000) / 1000.0 * 0.9

func blip(speaker: String) -> void:
	if speaker == "":
		return
	var p: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = _syllables[rng.randi_range(0, _syllables.size() - 1)]
	p.pitch_scale = voice_pitch(speaker) * rng.randf_range(0.9, 1.12)
	p.play()

## A short burst of babble, for one-line speech that pops up as a toast.
func babble(speaker: String, syllables: int) -> void:
	for i in syllables:
		blip(speaker)
		await get_tree().create_timer(0.085).timeout

func ring() -> void:
	_ring_player.stream = _ring
	_ring_player.play()

func stop_ring() -> void:
	_ring_player.stop()

func horn() -> void:
	var p: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = _horn
	p.pitch_scale = 1.0
	p.play()

## "Gus: \"...\"" -> "Gus". Empty when the line isn't somebody talking.
static func speaker_of(line: String) -> String:
	var i := line.find(": \"")
	if i <= 0 or i > 26:
		return ""
	var name := line.substr(0, i)
	for c in name:
		if not (c == " " or c == "." or c == "'" or (c.to_lower() != c.to_upper())):
			return ""
	return name
