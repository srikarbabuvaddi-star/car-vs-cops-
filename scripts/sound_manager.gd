class_name SoundManager
extends Node

static var instance: SoundManager

var _audio_players: Array[AudioStreamPlayer] = []
var _sfx_enabled: bool = true

# Cached 16-bit 44.1kHz AudioStreamWAV samples
var _snd_nitro: AudioStreamWAV
var _snd_skid: AudioStreamWAV
var _snd_crash: AudioStreamWAV
var _snd_close_call: AudioStreamWAV
var _snd_pickup: AudioStreamWAV
var _snd_win: AudioStreamWAV
var _snd_fail: AudioStreamWAV
var _snd_blip: AudioStreamWAV
var _snd_siren_wail: AudioStreamWAV
var _snd_siren_yelp: AudioStreamWAV
var _snd_engine: AudioStreamWAV
var _snd_explosion: AudioStreamWAV

var _engine_player: AudioStreamPlayer
var _siren_player: AudioStreamPlayer
var _current_siren_mode: String = ""

const SAMPLE_RATE: int = 44100

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_audio_pool(12)
	_setup_continuous_players()
	_generate_sound_effects()

func _create_audio_pool(count: int) -> void:
	for i in range(count):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_audio_players.append(player)

func _setup_continuous_players() -> void:
	_engine_player = AudioStreamPlayer.new()
	_engine_player.bus = "Master"
	_engine_player.volume_db = -2.0
	add_child(_engine_player)

	_siren_player = AudioStreamPlayer.new()
	_siren_player.bus = "Master"
	_siren_player.volume_db = -4.0
	add_child(_siren_player)

func _get_available_player() -> AudioStreamPlayer:
	for p in _audio_players:
		if not p.playing:
			return p
	return _audio_players[0]

func _generate_sound_effects() -> void:
	_snd_blip = _create_blip_16bit()
	_snd_pickup = _create_pickup_16bit()
	_snd_close_call = _create_close_call_16bit()
	_snd_crash = _create_crash_16bit()
	_snd_explosion = _create_explosion_16bit()
	_snd_skid = _create_skid_16bit()
	_snd_nitro = _create_nitro_16bit()
	_snd_win = _create_win_16bit()
	_snd_fail = _create_fail_16bit()
	_snd_siren_wail = _create_realistic_siren_wail_16bit()
	_snd_siren_yelp = _create_realistic_siren_yelp_16bit()
	_snd_engine = _create_realistic_v8_engine_16bit()

# Public playback methods
func play_blip() -> void:
	_play_stream(_snd_blip)

func play_pickup() -> void:
	_play_stream(_snd_pickup)

func play_close_call() -> void:
	_play_stream(_snd_close_call)

func play_crash() -> void:
	_play_stream(_snd_crash)

func play_explosion() -> void:
	_play_stream(_snd_explosion)

func play_skid() -> void:
	_play_stream(_snd_skid)

func play_nitro() -> void:
	_play_stream(_snd_nitro)

func play_win() -> void:
	_play_stream(_snd_win)

func play_fail() -> void:
	_play_stream(_snd_fail)

func play_siren(is_urgent: bool = false) -> void:
	if not _sfx_enabled or not _siren_player:
		return
	var target_stream = _snd_siren_yelp if is_urgent else _snd_siren_wail
	var mode_tag = "yelp" if is_urgent else "wail"

	if not _siren_player.playing or _current_siren_mode != mode_tag:
		_current_siren_mode = mode_tag
		_siren_player.stream = target_stream
		_siren_player.play()

func stop_siren() -> void:
	if _siren_player and _siren_player.playing:
		_siren_player.stop()
	_current_siren_mode = ""

func update_engine_pitch(speed_ratio: float, is_nitro: bool = false) -> void:
	if not _sfx_enabled or not _engine_player:
		return
	if not _engine_player.playing and _snd_engine:
		_engine_player.stream = _snd_engine
		_engine_player.play()

	var ratio = clamp(speed_ratio, 0.0, 1.0)
	# Physical V8 RPM sweep: Idle (850 RPM) -> High Rev (6800 RPM)
	var base_pitch = lerpf(0.85, 2.65, pow(ratio, 0.75))
	if is_nitro:
		base_pitch = min(3.1, base_pitch * 1.22)
		_engine_player.volume_db = 2.5
	else:
		_engine_player.volume_db = lerpf(-3.0, 1.5, ratio)

	_engine_player.pitch_scale = base_pitch

func stop_engine() -> void:
	if _engine_player and _engine_player.playing:
		_engine_player.stop()

func stop_all() -> void:
	stop_engine()
	stop_siren()
	for p in _audio_players:
		if p.playing:
			p.stop()

func _play_stream(stream: AudioStreamWAV) -> void:
	if not _sfx_enabled or not stream:
		return
	var player = _get_available_player()
	player.stream = stream
	player.play()

# -------------------------------------------------------------------------
# 16-BIT 44.1kHz AUDIO BUILDER HELPER
# -------------------------------------------------------------------------
func _build_wav_16bit(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var total = samples.size()
	var bytes = PackedByteArray()
	bytes.resize(total * 2)
	for i in range(total):
		var s = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, s)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = total
	return wav

# -------------------------------------------------------------------------
# REALITY-ACCURATE AUDIO SYNTHESIS
# -------------------------------------------------------------------------

# 1. Physical V8 Sports Car Engine (Crossplane Cylinder Firing Combustion Model)
func _create_realistic_v8_engine_16bit() -> AudioStreamWAV:
	var duration = 0.5 # 0.5s loop with exact 30 cycles at 60Hz (phase-locked!)
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var f0 = 60.0 # 60Hz firing pulse fundamental at idle (900 RPM V8)
	var filter_noise = 0.0

	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		var phase = t * f0 * TAU
		var cycle_frac = fposmod(phase / TAU, 1.0)

		# Asymmetric combustion stroke pressure wave: sharp attack + exponential decay
		var pulse = sin(phase) * exp(-cycle_frac * 3.4)

		# Manifold harmonic resonance (crossplane exhaust collector pulses)
		var h2 = sin(phase * 2.0) * 0.32
		var h3 = sin(phase * 3.0) * 0.16
		var h4 = sin(phase * 4.0) * 0.12

		# Deep sub-bass exhaust tail rumble (30Hz)
		var sub_rumble = sin(t * 30.0 * TAU) * 0.25

		# Mechanical gear whine & intake suction flutter
		var gear_whine = sin(phase * 5.0) * 0.08
		var white = randf() * 2.0 - 1.0
		filter_noise = lerpf(filter_noise, white, 0.15)
		var intake = filter_noise * 0.07

		# Composite sports car exhaust acoustic wave
		var raw_engine = (pulse * 0.55 + h2 + h3 + h4 + sub_rumble + gear_whine + intake)
		# Soft saturation for authentic muscle car growl
		samples[i] = clamp(raw_engine * 0.95, -1.0, 1.0) * 0.78

	return _build_wav_16bit(samples, true)

# 2. Federal Signal / Whelen Realistic Police Siren Horn (WAIL MODE - 1.8s Pursuit Sweep)
func _create_realistic_siren_wail_16bit() -> AudioStreamWAV:
	var duration = 1.8 # 1.8 second pursuit wail
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var phase_acc = 0.0
	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		# Smooth sinusoidal frequency modulation between 560Hz and 1220Hz
		var lfo = (sin(t / duration * TAU) * 0.5 + 0.5)
		var freq = lerpf(560.0, 1220.0, lfo)

		phase_acc += freq / float(SAMPLE_RATE) * TAU
		var w = phase_acc

		# 100W Emergency Speaker Horn Acoustic Driver (Saturated Odd Harmonics)
		# Fundamental + 3rd harmonic + 5th harmonic + 7th harmonic
		var raw_horn = sin(w) + 0.38 * sin(w * 3.0) + 0.16 * sin(w * 5.0) + 0.07 * sin(w * 7.0)
		# Saturated horn projector compression
		var saturated_horn = clamp(raw_horn * 1.35, -1.0, 1.0)
		samples[i] = saturated_horn * 0.42

	return _build_wav_16bit(samples, true)

# 3. Federal Signal / Whelen Realistic Police Siren Horn (YELP MODE - 0.25s Fast Urgent Sweep)
func _create_realistic_siren_yelp_16bit() -> AudioStreamWAV:
	var duration = 0.25 # 4 sweeps per second urgent chase yelp
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var phase_acc = 0.0
	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		# Fast linear/exponential upward sweep: 640Hz to 1320Hz
		var sweep_ratio = t / duration
		var freq = lerpf(640.0, 1320.0, pow(sweep_ratio, 0.85))

		phase_acc += freq / float(SAMPLE_RATE) * TAU
		var w = phase_acc

		var raw_horn = sin(w) + 0.40 * sin(w * 3.0) + 0.18 * sin(w * 5.0) + 0.08 * sin(w * 7.0)
		var saturated_horn = clamp(raw_horn * 1.4, -1.0, 1.0)
		samples[i] = saturated_horn * 0.45

	return _build_wav_16bit(samples, true)

# 4. Crash Impact (Sub-bass drop + high energy metal/glass crunch)
func _create_crash_16bit() -> AudioStreamWAV:
	var duration = 0.45
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var last_noise = 0.0
	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		var env = pow(1.0 - (float(i) / float(total)), 2.2)
		var sub_freq = lerpf(160.0, 35.0, pow(t / duration, 0.6))
		var sub = sin(t * sub_freq * TAU) * 0.75 * env
		var white = randf() * 2.0 - 1.0
		last_noise = lerpf(last_noise, white, 0.35)
		var crunch = last_noise * 0.45 * env
		samples[i] = (sub + crunch) * 0.85

	return _build_wav_16bit(samples, false)

# 5. Explosion (Massive cinematic cop-wreck blast with deep sub rumble)
func _create_explosion_16bit() -> AudioStreamWAV:
	var duration = 0.8
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var filter_val = 0.0
	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		var env = pow(1.0 - (float(i) / float(total)), 1.8)
		var sub_freq = lerpf(140.0, 28.0, pow(t / duration, 0.5))
		var sub = sin(t * sub_freq * TAU) * 0.8 * env
		var white = randf() * 2.0 - 1.0
		filter_val = lerpf(filter_val, white, 0.18)
		var blast = filter_val * 0.55 * env
		samples[i] = (sub + blast) * 0.9

	return _build_wav_16bit(samples, false)

# 6. Drift Tire Screech (Burning rubber with resonant bandpass)
func _create_skid_16bit() -> AudioStreamWAV:
	var duration = 0.3
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		var env = sin((float(i) / float(total)) * PI)
		var tone1 = sin(t * (920.0 + sin(t * 80.0) * 40.0) * TAU)
		var tone2 = sin(t * (1420.0 + sin(t * 120.0) * 60.0) * TAU) * 0.6
		var noise = (randf() * 2.0 - 1.0) * 0.3
		samples[i] = (tone1 + tone2 + noise) * 0.32 * env

	return _build_wav_16bit(samples, false)

# 7. Nitro Jet Boost (Rushing turbine ignition with sub thrust)
func _create_nitro_16bit() -> AudioStreamWAV:
	var duration = 0.45
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var lpf = 0.0
	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		var env = sin(pow(float(i) / float(total), 0.6) * PI)
		var core = sin(t * 75.0 * TAU) * 0.45
		var cutoff = lerpf(0.15, 0.45, env)
		var white = randf() * 2.0 - 1.0
		lpf = lerpf(lpf, white, cutoff)
		samples[i] = (core + lpf * 0.55) * 0.7 * env

	return _build_wav_16bit(samples, false)

# 8. Close Call Chime (Ascending shimmering crystal arpeggio)
func _create_close_call_16bit() -> AudioStreamWAV:
	var notes = [659.25, 830.61, 987.77, 1318.5, 1975.5]
	var note_dur = 0.055
	var total = int(SAMPLE_RATE * note_dur * notes.size()) + int(SAMPLE_RATE * 0.15)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var note_samples = int(SAMPLE_RATE * note_dur)
	for n in range(notes.size()):
		var freq = notes[n]
		var start = n * note_samples
		for j in range(int(SAMPLE_RATE * 0.2)):
			var idx = start + j
			if idx >= total:
				break
			var t = float(j) / float(SAMPLE_RATE)
			var env = exp(-t * 12.0)
			var bell = (sin(t * freq * TAU) + sin(t * freq * 2.0 * TAU) * 0.35) * env
			samples[idx] += bell * 0.28

	return _build_wav_16bit(samples, false)

# 9. Arcade Pickup Double-Chime (Bright coin sparkle)
func _create_pickup_16bit() -> AudioStreamWAV:
	var notes = [1318.5, 1760.0]
	var note_dur = 0.06
	var total = int(SAMPLE_RATE * 0.28)
	var samples = PackedFloat32Array()
	samples.resize(total)

	var note_samples = int(SAMPLE_RATE * note_dur)
	for n in range(notes.size()):
		var freq = notes[n]
		var start = n * note_samples
		for j in range(int(SAMPLE_RATE * 0.18)):
			var idx = start + j
			if idx >= total:
				break
			var t = float(j) / float(SAMPLE_RATE)
			var env = exp(-t * 14.0)
			var val = (sin(t * freq * TAU) + sin(t * freq * 3.0 * TAU) * 0.2) * env
			samples[idx] += val * 0.38

	return _build_wav_16bit(samples, false)

# 10. Triumphant Win Fanfare (Rich brass arpeggio)
func _create_win_16bit() -> AudioStreamWAV:
	var freqs = [523.25, 659.25, 783.99, 1046.5]
	var note_dur = 0.12
	var total = int(SAMPLE_RATE * (note_dur * freqs.size() + 0.35))
	var samples = PackedFloat32Array()
	samples.resize(total)

	var note_samples = int(SAMPLE_RATE * note_dur)
	for n in range(freqs.size()):
		var freq = freqs[n]
		var start = n * note_samples
		for j in range(int(SAMPLE_RATE * 0.4)):
			var idx = start + j
			if idx >= total:
				break
			var t = float(j) / float(SAMPLE_RATE)
			var env = exp(-t * 5.0)
			var brass = (sin(t * freq * TAU) + sin(t * freq * 2.0 * TAU) * 0.4 + sin(t * freq * 3.0 * TAU) * 0.2) * env
			samples[idx] += brass * 0.25

	return _build_wav_16bit(samples, false)

# 11. Ominous Fail Bass Drop (System crash impact)
func _create_fail_16bit() -> AudioStreamWAV:
	var duration = 0.55
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		var env = pow(1.0 - (float(i) / float(total)), 1.5)
		var freq = lerpf(150.0, 38.0, pow(t / duration, 0.7))
		var bass = sin(t * freq * TAU) * 0.7 + sin(t * (freq * 1.33) * TAU) * 0.3
		samples[i] = bass * env * 0.75

	return _build_wav_16bit(samples, false)

# 12. Futuristic UI Blip
func _create_blip_16bit() -> AudioStreamWAV:
	var duration = 0.04
	var total = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(total)

	for i in range(total):
		var t = float(i) / float(SAMPLE_RATE)
		var env = 1.0 - (float(i) / float(total))
		var freq = lerpf(1200.0, 700.0, t / duration)
		samples[i] = sin(t * freq * TAU) * env * 0.35

	return _build_wav_16bit(samples, false)
