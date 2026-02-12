class_name AudioGenerator
extends RefCounted
## Generates procedural AudioStreamWAV sounds for use when real audio files are missing.
## All sounds are 22050 Hz mono 16-bit PCM.

const SAMPLE_RATE := 22050
const MAX_16 := 32767.0


static func generate_all_sfx() -> Dictionary:
	## Returns {sfx_name: AudioStreamWAV} for all procedural sounds.
	return {
		"footstep_1": _gen_footstep(0.8),
		"footstep_2": _gen_footstep(1.1),
		"ui_click": _gen_click(),
		"notification": _gen_notification(),
		"conversation_start": _gen_conversation_start(),
		"conversation_murmur": _gen_murmur(),
		"conversation_end": _gen_conversation_end(),
		"coffee_pour": _gen_pour(),
		"typing": _gen_typing(),
		"book_flip": _gen_flip(),
		"death_sad": _gen_sad(),
		"romance_chime": _gen_romance(),
		"group_formed": _gen_group(),
		"achievement": _gen_achievement(),
		"heartbreak": _gen_heartbreak(),
	}


static func generate_music_calm() -> AudioStreamWAV:
	## Generate a gentle ambient loop (~8 seconds).
	var duration := 8.0
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# Layered sine waves with slow modulation for an ambient feel
	var freqs: Array[float] = [130.81, 196.0, 261.63, 329.63]  # C3, G3, C4, E4
	var amps: Array[float] = [0.25, 0.2, 0.15, 0.1]

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var val: float = 0.0

		for j in range(freqs.size()):
			# Each voice has slow vibrato
			var vibrato: float = sin(t * (0.3 + j * 0.15)) * 2.0
			val += sin(TAU * (freqs[j] + vibrato) * t) * amps[j]

		# Gentle volume swell
		var envelope: float = 0.7 + sin(t * 0.5) * 0.3

		# Crossfade loop: fade in first 0.5s, fade out last 0.5s
		var fade_in: float = clampf(t / 0.5, 0.0, 1.0)
		var fade_out: float = clampf((duration - t) / 0.5, 0.0, 1.0)

		val *= envelope * fade_in * fade_out * 0.5
		var sample_i: int = clampi(int(val * MAX_16), -32768, 32767)
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = int(0.5 * SAMPLE_RATE)
	stream.loop_end = samples - int(0.5 * SAMPLE_RATE)
	return stream


# --- Individual SFX generators ---

static func _gen_footstep(pitch: float) -> AudioStreamWAV:
	## Short noise burst filtered to sound like a soft step.
	var duration := 0.08
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev: float = 0.0

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / duration) * (1.0 - t / duration)
		# Noise
		var noise: float = randf_range(-1.0, 1.0)
		# Simple low-pass (one-pole)
		var cutoff: float = 0.15 / pitch
		prev = prev + cutoff * (noise - prev)
		var val: float = prev * env * 0.6
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_click() -> AudioStreamWAV:
	var duration := 0.03
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / duration) * (1.0 - t / duration)
		var val: float = sin(TAU * 2400.0 * t) * env * 0.4
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_notification() -> AudioStreamWAV:
	## Two rising tones.
	var duration := 0.3
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = maxf(0.0, 1.0 - t / duration)
		var freq: float = 880.0 + t * 400.0
		var val: float = sin(TAU * freq * t) * env * 0.35
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_conversation_start() -> AudioStreamWAV:
	## Two quick ascending notes.
	var duration := 0.2
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var freq: float = 523.25 if t < 0.1 else 659.25  # C5, E5
		var local_t: float = t if t < 0.1 else t - 0.1
		var env: float = maxf(0.0, 1.0 - local_t / 0.1)
		var val: float = sin(TAU * freq * t) * env * 0.3
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_murmur() -> AudioStreamWAV:
	## Filtered noise resembling distant speech.
	var duration := 0.4
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev: float = 0.0
	var prev2: float = 0.0

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(PI * t / duration) * 0.3
		var noise: float = randf_range(-1.0, 1.0)
		# Band-pass using two one-pole filters
		prev = prev + 0.08 * (noise - prev)
		prev2 = prev2 + 0.3 * (prev - prev2)
		var val: float = (prev - prev2) * env * 3.0
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_conversation_end() -> AudioStreamWAV:
	## Descending tone.
	var duration := 0.15
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = maxf(0.0, 1.0 - t / duration)
		var freq: float = 659.25 - t * 800.0  # E5 descending
		var val: float = sin(TAU * freq * t) * env * 0.25
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_pour() -> AudioStreamWAV:
	## Filtered noise resembling liquid pouring.
	var duration := 0.5
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev: float = 0.0

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(PI * t / duration) * 0.35
		var noise: float = randf_range(-1.0, 1.0)
		var cutoff: float = 0.05 + sin(t * 30.0) * 0.02
		prev = prev + cutoff * (noise - prev)
		var val: float = prev * env
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_typing() -> AudioStreamWAV:
	## Short staccato clicks like keyboard typing.
	var duration := 0.3
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# 4 clicks at different times
		var val: float = 0.0
		for click_idx in range(4):
			var click_t: float = click_idx * 0.07
			var dt: float = t - click_t
			if dt >= 0.0 and dt < 0.015:
				var env: float = (1.0 - dt / 0.015) * (1.0 - dt / 0.015)
				var freq: float = 3000.0 + click_idx * 200.0
				val += sin(TAU * freq * dt) * env * 0.2
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_flip() -> AudioStreamWAV:
	## Quick swoosh sound.
	var duration := 0.12
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev: float = 0.0

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = maxf(0.0, 1.0 - t / duration)
		var noise: float = randf_range(-1.0, 1.0)
		var cutoff: float = 0.3 - t * 2.0
		cutoff = clampf(cutoff, 0.02, 0.5)
		prev = prev + cutoff * (noise - prev)
		var val: float = prev * env * 0.5
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_sad() -> AudioStreamWAV:
	## Descending minor chord, slow fade.
	var duration := 1.0
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# D minor: D4, F4, A4 descending
	var freqs: Array[float] = [293.66, 349.23, 440.0]
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = maxf(0.0, 1.0 - t / duration) * maxf(0.0, 1.0 - t / duration)
		var val: float = 0.0
		for j in range(freqs.size()):
			var freq: float = freqs[j] * (1.0 - t * 0.15)
			val += sin(TAU * freq * t) * 0.2
		val *= env
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_romance() -> AudioStreamWAV:
	## Rising major arpeggio with sparkle.
	var duration := 0.6
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	# C major arpeggio: C5, E5, G5, C6
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var note_dur := 0.15

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var val: float = 0.0
		for j in range(notes.size()):
			var start_t: float = j * note_dur
			var dt: float = t - start_t
			if dt >= 0.0:
				var note_env: float = maxf(0.0, 1.0 - dt / (note_dur * 2.0))
				val += sin(TAU * notes[j] * t) * note_env * 0.2
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_group() -> AudioStreamWAV:
	## Quick ascending major arpeggio.
	var duration := 0.35
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	var notes: Array[float] = [392.0, 493.88, 587.33, 783.99]  # G4, B4, D5, G5
	var note_dur := 0.08

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var val: float = 0.0
		for j in range(notes.size()):
			var start_t: float = j * note_dur
			var dt: float = t - start_t
			if dt >= 0.0 and dt < note_dur * 2:
				var note_env: float = maxf(0.0, 1.0 - dt / (note_dur * 2.0))
				val += sin(TAU * notes[j] * t) * note_env * 0.25
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_achievement() -> AudioStreamWAV:
	## Triumphant two-note fanfare.
	var duration := 0.5
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var val: float = 0.0
		# Note 1: G5 (0.0 - 0.2s)
		if t < 0.25:
			var env: float = minf(t / 0.02, 1.0) * maxf(0.0, 1.0 - t / 0.25)
			val += sin(TAU * 783.99 * t) * env * 0.3
			val += sin(TAU * 783.99 * 2.0 * t) * env * 0.1  # Overtone
		# Note 2: C6 (0.15s - 0.5s)
		if t >= 0.15:
			var dt: float = t - 0.15
			var env: float = minf(dt / 0.02, 1.0) * maxf(0.0, 1.0 - dt / 0.35)
			val += sin(TAU * 1046.50 * t) * env * 0.35
			val += sin(TAU * 1046.50 * 2.0 * t) * env * 0.1
		_write_sample(data, i, val)

	return _make_wav(data, samples)


static func _gen_heartbreak() -> AudioStreamWAV:
	## Descending minor second interval.
	var duration := 0.6
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = maxf(0.0, 1.0 - t / duration) * maxf(0.0, 1.0 - t / duration)
		# E5 descending to Eb5 (minor second)
		var freq: float = 659.25 - t * 20.0
		var val: float = sin(TAU * freq * t) * env * 0.35
		# Add dissonant second voice
		val += sin(TAU * (freq - 15.0) * t) * env * 0.2
		_write_sample(data, i, val)

	return _make_wav(data, samples)


# --- Helpers ---

static func _write_sample(data: PackedByteArray, idx: int, val: float) -> void:
	var sample_i: int = clampi(int(val * MAX_16), -32768, 32767)
	data[idx * 2] = sample_i & 0xFF
	data[idx * 2 + 1] = (sample_i >> 8) & 0xFF


static func _make_wav(data: PackedByteArray, _samples: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
