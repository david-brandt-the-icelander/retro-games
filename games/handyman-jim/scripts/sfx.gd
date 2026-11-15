extends Node
## Every sound in the game. The phone ring and the horn are synthesised at start-up; the
## "bla-bla" speech is random 150 ms slices of a muffled public-domain recording
## (audio/voice.wav, see audio/CREDITS.md), pitch-shifted per speaker so it sounds like
## real people mumbling behind a wall.

const RATE := 22050
const VOICE := preload("res://audio/voice.wav")
## Start times (seconds) in voice.wav where a syllable begins, picked from the clip's loudness.
const GRAINS := [0.09,0.349,0.998,1.207,2.514,2.903,3.821,4.091,4.42,4.55,4.699,4.949,6.745,6.884,7.034,7.383,7.693,7.912,8.331,9.119,9.389,9.838,10.187,11.324,11.554,11.863,12.651,12.781,13.15,13.659,14.507,15.505,15.834]
const GRAIN_LEN := 0.15
const VOICE_DB := -3.0

var _fades := {}   # player -> its running fade tween
var _ring: AudioStreamWAV
var _horn: AudioStreamWAV
var _voices: Array = []
var _next := 0
var _ring_player: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
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
		return 0.8                                         # Jim: the lowest voice in town
	var h := absi(k.hash())
	return 0.88 + float(h % 1000) / 1000.0 * 0.5     # everyone else: 0.88 - 1.38

## One mumbled syllable in this speaker's voice: a random slice of the recording, faded out.
func blip(speaker: String) -> void:
	if speaker == "":
		return
	var p: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	if _fades.has(p) and _fades[p].is_valid():
		_fades[p].kill()
	p.stream = VOICE
	p.pitch_scale = voice_pitch(speaker) * rng.randf_range(0.94, 1.08)
	p.volume_db = VOICE_DB
	p.play(GRAINS[rng.randi_range(0, GRAINS.size() - 1)])
	var tw := create_tween()
	tw.tween_interval(GRAIN_LEN * 0.7)
	tw.tween_property(p, "volume_db", -40.0, GRAIN_LEN * 0.3)
	tw.tween_callback(p.stop)
	_fades[p] = tw

## A short burst of babble, for one-line speech that pops up as a toast.
func babble(speaker: String, syllables: int) -> void:
	for i in syllables:
		blip(speaker)
		await get_tree().create_timer(0.13).timeout

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
