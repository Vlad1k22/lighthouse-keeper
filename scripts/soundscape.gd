extends Node
## Синтезированные звуки: прибой, шаги и взаимодействие.
var sea: AudioStreamPlayer
var steps: AudioStreamPlayer
var effect: AudioStreamPlayer

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
		else:
			value = sin(t * TAU * lerpf(520, 760, t / duration)) * pow(1.0 - t / duration, 2) * 0.35
		data.encode_s16(index * 2, int(clampf(value, -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	if kind == 0:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream

func footstep() -> void:
	if not steps.playing:
		steps.play()

func interact() -> void:
	effect.play()

func _exit_tree() -> void:
	for audio_player in [sea, steps, effect]:
		if is_instance_valid(audio_player):
			audio_player.stop()
			audio_player.stream = null
