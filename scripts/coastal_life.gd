extends Node3D
## Живое окружение: чайки, качка лодки, свет и плавная смена погоды.
@export_enum("Автоматически", "Дождь", "Без дождя") var weather_mode: int = 0
var rain_strength := 0.0
var night_strength := 0.0
var clock := 0.0
var story_storm := false
var boat: Node3D
var boat_origin := Vector3.ZERO
var lamps: Array[OmniLight3D] = []

func _ready() -> void:
	boat = get_parent().find_child("FishingBoat", true, false)
	if is_instance_valid(boat):
		boat_origin = boat.position
	for light in get_parent().find_children("PathLantern*", "OmniLight3D", true, false):
		lamps.append(light)

func _process(delta: float) -> void:
	clock += delta
	var target := 0.7 if night_strength > 0.7 else 0.0
	if story_storm:target = 1.0
	if weather_mode == 1:
		target = 1.0
	elif weather_mode == 2:
		target = 0.0
	rain_strength = move_toward(rain_strength, target, delta * 0.35)
	$Rain.emitting = rain_strength > 0.01
	$Rain.material_override.albedo_color.a = rain_strength * 0.28
	$NightMotes.emitting = night_strength > 0.65 and rain_strength < 0.4
	get_parent().get_node("Ocean").material_override.set_shader_parameter("rain_amount", rain_strength)
	for index in $Gulls.get_child_count():
		var bird: Node3D = $Gulls.get_child(index)
		var phase := clock * 0.14 + index * 2.1
		bird.position = Vector3(cos(phase) * (18 + index * 2), 8 + sin(phase * 2) * 0.8 + index * 0.8, sin(phase) * 12 - 3)
		bird.rotation.y = -phase
		bird.get_node("LeftWing").rotation.z = sin(clock * 3.0 + index) * 0.23
		bird.get_node("RightWing").rotation.z = -sin(clock * 3.0 + index) * 0.23
		bird.visible = night_strength < 0.85
	if is_instance_valid(boat):
		boat.position = boat_origin + Vector3(0, sin(clock * 1.4) * 0.065, 0)
		boat.rotation.z = sin(clock * 1.1) * 0.025
	for index in lamps.size():
		lamps[index].light_energy = 1.8 + sin(clock * 2 + index * 3) * 0.09 + sin(clock * 7 + index) * 0.035

func cycle_weather() -> void:
	weather_mode = (weather_mode + 1) % 3

func weather_label() -> String:
	return "ДОЖДЬ · ВЕТЕР С МОРЯ" if rain_strength > 0.2 else "ПАСМУРНО · ВЕТЕР С МОРЯ"
