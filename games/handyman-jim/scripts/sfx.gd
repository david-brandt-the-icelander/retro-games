extends Node
## Every sound in the game. The phone ring and the horn are synthesised at start-up. Speech is
## a muffled public-domain recording (audio/voice.wav, see audio/CREDITS.md) played as whole
## phrases of real words while a person's line types out, slowed and deepened per speaker, so it
## sounds like people mumbling behind a wall.

const RATE := 22050
const VOICE := preload("res://audio/voice.wav")
## Start times (seconds) in voice.wav where a spoken phrase begins, right after a pause.
const PHRASES := [2.48, 3.79, 4.39, 6.08, 6.71, 8.3, 9.09, 11.29, 11.83, 13.12, 15.22, 18.04, 19.19, 19.64, 22.14, 23.1, 26.09, 28.58, 30.59, 31.94, 34.1, 35.73, 36.05, 37.27, 40.51, 42.81, 43.81]
const VOICE_DB := -3.0

var _talk: AudioStreamPlayer      # the one voice that speaks the current line
var _talk_fade: Tween
var _talker := ""                  # who is speaking now ("" = nobody)
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
	_talk = AudioStreamPlayer.new()
	_talk.stream = VOICE
	add_child(_talk)
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
		return 0.62                                        # Jim: the lowest voice in town
	var h := absi(k.hash())
	return 0.7 + float(h % 1000) / 1000.0 * 0.32     # everyone else: 0.70 - 1.02

## Start (or keep) speaking as this person: real words from the recording, from the start of a
## random phrase, at the speaker's own pitch. Calling it again for the same speaker changes nothing.
func talk(speaker: String) -> void:
	if speaker == "":
		hush()
		return
	if speaker == _talker and _talk.playing:
		return
	_talker = speaker
	if _talk_fade and _talk_fade.is_valid():
		_talk_fade.kill()
	_talk.pitch_scale = voice_pitch(speaker)
	_talk.volume_db = VOICE_DB
	_talk.play(PHRASES[rng.randi_range(0, PHRASES.size() - 1)])

## Stop talking with a short fade, so words trail off rather than click off.
func hush() -> void:
	if _talker == "" and not _talk.playing:
		return
	_talker = ""
	if _talk_fade and _talk_fade.is_valid():
		_talk_fade.kill()
	_talk_fade = create_tween()
	_talk_fade.tween_property(_talk, "volume_db", -40.0, 0.25)
	_talk_fade.tween_callback(_talk.stop)

## A pop-up remark: the speaker talks for about as long as the line takes to read aloud.
func remark(speaker: String, text: String) -> void:
	talk(speaker)
	await get_tree().create_timer(clampf(text.length() * 0.06, 0.8, 2.5)).timeout
	if _talker == speaker:
		hush()

func _process(_dt: float) -> void:
	# at the end of the recording, carry on from another phrase rather than falling silent
	if _talker != "" and not _talk.playing:
		var who := _talker
		_talker = ""
		talk(who)

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
