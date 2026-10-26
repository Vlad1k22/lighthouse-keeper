extends Node
## Синтезированные звуки: прибой, шаги и взаимодействие.
var sea: AudioStreamPlayer
var steps: AudioStreamPlayer
var effect: AudioStreamPlayer
var rainfall: AudioStreamPlayer
var drone: AudioStreamPlayer
var radio: AudioStreamPlayer
var engine: AudioStreamPlayer
var horror_cache := {}

func _ready() -> void:
	sea = AudioStreamPlayer.new()
	sea.stream = noise_stream(5.0, 0)
	sea.volume_db = -25
	add_child(sea)
	sea.play()
	steps = AudioStreamPlayer.new()
	steps.stream = noise_stream(0.13, 1)
	steps.volume_db = -17
	add_child(steps)
	effect = AudioStreamPlayer.new()
	effect.stream = noise_stream(0.3, 2)
	effect.volume_db = -20
	add_child(effect)
	rainfall = looping_player(3, 3.0)
	drone = looping_player(4, 6.0)
	radio = AudioStreamPlayer.new()
	radio.stream = noise_stream(0.85, 5)
	radio.volume_db = -23
	add_child(radio)
	engine = looping_player(6,4.0)

func looping_player(kind: int, duration: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.stream = noise_stream(duration, kind)
	audio.volume_db = -70
	add_child(audio)
	audio.play()
	return audio

func set_ambience(night: float, rain: float) -> void:
	rainfall.volume_db = lerpf(-70, -24, rain)
	drone.volume_db = lerpf(-70, -34, night)

func set_engine(distance: float, running: bool) -> void:
	engine.volume_db = lerpf(-70,-26,clampf(1-distance/18.0,0,1)) if running else -70.0

func set_story_silence(silent: bool) -> void:
	sea.volume_db = -65 if silent else -25
	if silent:
		rainfall.volume_db = -65
		drone.volume_db = -70

func noise_stream(duration: float, kind: int) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 127 + kind
	var filtered := 0.0
	for index in count:
		var t := float(index) / rate
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.07 if kind == 0 else 0.45)
		var value := 0.0
		if kind == 0:
			value = filtered * (0.55 + 0.3 * sin(TAU * t / duration)) + sin(t * 80) * 0.008
		elif kind == 1:
			value = (filtered * 0.7 + sin(t * 95) * 0.2) * pow(1.0 - float(index) / count, 2)
		elif kind == 2:
			value = sin(t * TAU * lerpf(520, 760, t / duration)) * pow(1.0 - t / duration, 2) * 0.35
		elif kind == 3:
			value = filtered * 0.7 + rng.randf_range(-0.1, 0.1)
		elif kind == 4:
			value = (sin(TAU * t * 110) + sin(TAU * t * 130.833333) * 0.6 + sin(TAU * t * 164.833333) * 0.3) * 0.11
			value *= 0.8 + sin(TAU * t / duration) * 0.2
		elif kind == 6:
			value = (sin(TAU*t*35)*0.2+sin(TAU*t*70)*0.07)*(0.85+sin(TAU*t*6)*0.15)+filtered*0.08
		elif kind==7:
			var beat := fmod(t,.23)
			value = (sin(t*TAU*72)*.55+filtered*.2)*exp(-beat*38)
		elif kind==8:
			value = (filtered*.3+sin(t*TAU*163)*.035)*pow(sin(PI*t/duration),2)
		elif kind==9:
			value = filtered*.45*(.2+.8*maxf(0,sin(TAU*t*7)))
		else:
			value = (filtered * 0.6 + sin(t * TAU * 820) * 0.12) * pow(sin(PI * t / duration), 2)
		data.encode_s16(index * 2, int(clampf(value, -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	if kind in [0, 3, 4, 6]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream

func footstep() -> void:
	if not steps.playing:
		steps.pitch_scale = randf_range(0.88, 1.1)
		steps.play()

func interact(kind: String = "") -> void:
	effect.pitch_scale = {"wood": 0.7, "beacon": 0.65, "cook": 1.15, "fish": 1.3}.get(kind, 1.0)
	effect.play()

func radio_signal() -> void:
	radio.play()

func horror_cue(kind: String, at: Vector3) -> void:
	var type: int = {"knock":7,"whisper":8,"radio":9,"steps":1}.get(kind,8)
	if not horror_cache.has(type):horror_cache[type]=noise_stream(.75 if type!=1 else .18,type)
	var cue := AudioStreamPlayer3D.new()
	cue.stream = horror_cache[type]
	cue.unit_size = 7
	cue.max_distance = 55
	cue.volume_db = -14
	add_child(cue)
	cue.global_position = at
	cue.finished.connect(cue.queue_free)
	cue.play()

func _exit_tree() -> void:
	for audio_player in [sea, steps, effect, rainfall, drone, radio, engine]:
		if is_instance_valid(audio_player):
			audio_player.stop()
			audio_player.stream = null
