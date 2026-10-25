extends RefCounted
## Самостоятельная модель рыбалки: ожидание, подсечка и удержание рыбы.
signal resolved(caught: bool)

enum Phase { IDLE, WAITING, BITE, REELING, RESULT }
const PROVISIONS = preload("res://scripts/provisions.gd")
const FISH = PROVISIONS.SPECIES
var rng := RandomNumberGenerator.new()
var phase := Phase.IDLE
var phase_time := 0.0
var waiting_time := 1.5
var fish: Dictionary = {}
var fish_position := 0.35
var fish_target := 0.5
var target_time := 0.0
var bar_position := 0.35
var bar_velocity := 0.0
var bar_size := 0.32
var progress := 0.35
var in_zone := true
var escaped_time := 0.0
var caught := false
var perfect := false
var weight := 0
var result_text := ""
var casts := 0

func _init() -> void:
	rng.randomize()

func is_open() -> bool:
	return phase != Phase.IDLE

func begin(seed_value: int = -1, species_id: String = "") -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	fish = PROVISIONS.definition(species_id) if not species_id.is_empty() else PROVISIONS.choose(rng, casts == 0)
	if fish.is_empty():
		fish = FISH[0].duplicate()
	casts += 1
	bar_size = float(fish.zone)
	waiting_time = rng.randf_range(1.2, 2.4)
	fish_position = 0.35
	fish_target = 0.52
	target_time = 0.8
	bar_position = 0.35
	bar_velocity = 0
	progress = 0.35
	escaped_time = 0
	in_zone = true
	caught = false
	perfect = false
	weight = 0
	result_text = ""
	set_phase(Phase.WAITING)

func set_phase(value: Phase) -> void:
	phase = value
	phase_time = 0

func press_action() -> void:
	if phase == Phase.BITE:
		set_phase(Phase.REELING)

func close() -> void:
	set_phase(Phase.IDLE)

func advance(delta: float, held: bool) -> void:
	if not is_open():
		return
	phase_time += delta
	match phase:
		Phase.WAITING:
			if phase_time >= waiting_time:
				set_phase(Phase.BITE)
		Phase.BITE:
			if phase_time >= 3.0:
				finish(false, "Рыба сняла наживку.\nПопробуйте подсечь быстрее.")
		Phase.REELING:
			# Малые шаги сохраняют поведение полоски при разной частоте кадров.
			var remaining := minf(delta, 0.1)
			while remaining > 0 and phase == Phase.REELING:
				var step := minf(remaining, 1.0 / 120.0)
				advance_reeling(step, held)
				remaining -= step

func advance_reeling(delta: float, held: bool) -> void:
	target_time -= delta
	if target_time <= 0:
		fish_target = rng.randf_range(0.12, 0.88)
		target_time = rng.randf_range(float(fish.turn_min), float(fish.turn_max))
	fish_position = move_toward(fish_position, fish_target, float(fish.speed) * delta)
	bar_velocity = clampf(bar_velocity + (2.4 if held else -1.7) * delta, -0.8, 0.8)
	bar_position += bar_velocity * delta
	var lower := bar_size * 0.5
	var upper := 1.0 - lower
	if bar_position < lower:
		bar_position = lower
		bar_velocity = absf(bar_velocity) * 0.15
	elif bar_position > upper:
		bar_position = upper
		bar_velocity = 0
	in_zone = absf(fish_position - bar_position) <= bar_size * 0.5 - 0.015
	progress = clampf(progress + (float(fish.gain) if in_zone else -float(fish.loss)) * delta, 0, 1)
	if not in_zone:
		escaped_time += delta
	if progress >= 1:
		weight = rng.randi_range(int(fish.min_weight), int(fish.max_weight))
		perfect = escaped_time < 0.25
		finish(true, "Улов отправлен в рюкзак.\nПриготовьте рыбу на печи\nвозле хижины.")
	elif progress <= 0:
		finish(false, "Леска ослабла — рыба ушла.\nНажимайте коротко, чтобы\nполоска двигалась плавнее.")

func finish(success: bool, reason: String) -> void:
	if phase == Phase.RESULT or phase == Phase.IDLE:
		return
	caught = success
	result_text = reason
	set_phase(Phase.RESULT)
	resolved.emit(success)
