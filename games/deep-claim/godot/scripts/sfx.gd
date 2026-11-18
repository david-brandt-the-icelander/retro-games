class_name Sfx
extends Node
## Tiny software synth: every sound effect and the ambient music loop are generated at startup.

const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _music: AudioStreamPlayer
var _jet: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_streams["jump"] = _synth([[280.0, 640.0, 0.11]], "square", 0.14)
	_streams["pickup"] = _synth([[1175.0, 1175.0, 0.05], [1568.0, 1568.0, 0.16]], "sine", 0.4)
	_streams["board"] = _synth([[440.0, 440.0, 0.06], [660.0, 660.0, 0.12]], "square", 0.1)
	_streams["unboard"] = _synth([[660.0, 660.0, 0.06], [440.0, 440.0, 0.12]], "square", 0.1)
	_streams["refuel"] = _synth([[900.0, 1100.0, 0.03]], "sine", 0.12)
	_streams["alarm"] = _synth([[1320.0, 1320.0, 0.09], [0.0, 0.0, 0.05], [1320.0, 1320.0, 0.09]], "square", 0.08)
	_streams["klaxon"] = _synth([[520.0, 380.0, 0.45]], "saw", 0.14)
	_streams["rumble"] = _synth([[60.0, 30.0, 1.6]], "noise", 0.35)
	_streams["crush"] = _synth([[200.0, 40.0, 0.35]], "noise", 0.4)
	_streams["door"] = _synth([[110.0, 220.0, 0.6], [523.0, 523.0, 0.08], [784.0, 784.0, 0.25]], "square", 0.12)
	_streams["crumble"] = _synth([[180.0, 60.0, 0.16]], "noise", 0.3)
	_streams["land"] = _synth([[120.0, 50.0, 0.07]], "noise", 0.18)
	_streams["die"] = _synth([[700.0, 50.0, 0.8]], "saw", 0.28)
	_streams["open"] = _synth([[523.0, 523.0, 0.07], [659.0, 659.0, 0.07], [784.0, 784.0, 0.07], [1047.0, 1047.0, 0.35]], "sine", 0.35)
	_streams["win"] = _synth([[392.0, 392.0, 0.09], [523.0, 523.0, 0.09], [659.0, 659.0, 0.09], [784.0, 784.0, 0.09], [1047.0, 1047.0, 0.5]], "square", 0.12)
	_streams["tick"] = _synth([[1800.0, 1800.0, 0.018]], "square", 0.06)
	_streams["start"] = _synth([[220.0, 880.0, 0.35]], "sine", 0.35)
	_streams["over"] = _synth([[392.0, 392.0, 0.25], [330.0, 330.0, 0.25], [262.0, 200.0, 0.7]], "saw", 0.2)
	_jet = AudioStreamPlayer.new()
	_jet.stream = _make_jet_loop()
	_jet.volume_db = -10.0
	add_child(_jet)
	_music = AudioStreamPlayer.new()
	_music.stream = _make_music()
	_music.volume_db = -14.0
	add_child(_music)
	_music.play()


func play(sound: String, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


func jet(on: bool) -> void:
	if _jet == null:
		return
	if on and not _jet.playing:
		_jet.play()
	elif not on and _jet.playing:
		_jet.stop()


func _make_jet_loop() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.18
		var flutter := 0.8 + 0.2 * sin(TAU * 18.0 * i / RATE)
		data.encode_s16(i * 2, int(clampf(lp * 1.6 * flutter, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _synth(segments: Array, wave: String, vol: float) -> AudioStreamWAV:
	var total := 0
	for s in segments:
		total += int(s[2] * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var i := 0
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noise_val := 0.0
	for s in segments:
		var n := int(s[2] * RATE)
		for k in n:
			var t := float(k) / n
			var f: float = lerpf(s[0], s[1], t)
			phase = fmod(phase + f / RATE, 1.0)
			var v := 0.0
			match wave:
				"sine":
					v = sin(TAU * phase)
				"square":
					v = 1.0 if phase < 0.5 else -1.0
				"saw":
					v = phase * 2.0 - 1.0
				"noise":
					if k % maxi(1, int(RATE / maxf(f * 2.0, 1.0))) == 0:
						noise_val = rng.randf_range(-1.0, 1.0)
					v = noise_val
			var env := 1.0 - t
			if wave != "sine":
				env *= env
			var attack := minf(1.0, k / (RATE * 0.004))
			data.encode_s16(i * 2, int(clampf(v * env * attack * vol, -1.0, 1.0) * 32767.0))
			i += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _make_music() -> AudioStreamWAV:
	# A slow, looping ambient pad: four chords with a soft bell arpeggio on top.
	var rate := 16000
	var bar := 2.4
	var chords := [[110.0, 164.81, 220.0, 261.63], [87.31, 130.81, 174.61, 220.0],
			[130.81, 196.0, 261.63, 329.63], [98.0, 146.83, 196.0, 246.94]]
	var n := int(bar * chords.size() * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var ci := int(t / bar) % chords.size()
		var lt := fmod(t, bar)
		var ch: Array = chords[ci]
		var pad := 0.0
		for j in ch.size():
			var f: float = ch[j]
			pad += sin(TAU * f * t) * (0.5 if j == 0 else 0.22) + sin(TAU * f * 1.003 * t) * 0.12
		var swell := sin(PI * lt / bar)
		pad *= 0.16 * (0.35 + 0.65 * swell)
		var step := 0.3
		var note_i := int(lt / step)
		var nt := fmod(lt, step)
		var bell := 0.0
		if note_i % 2 == 0:
			var bf: float = ch[(note_i / 2) % ch.size()] * 4.0
			bell = sin(TAU * bf * nt) * exp(-nt * 9.0) * 0.07
		data.encode_s16(i * 2, int(clampf(pad + bell, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
