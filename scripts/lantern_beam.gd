extends Node3D
## Сфокусированный луч ручного фонаря (ПКМ или C) и обжигающий луч маяка.
## Луч выжигает «тьму» теней: так ночь превращается из ожидания в активную оборону.
const RANGE := 7.6
const HALF_ANGLE := 0.42
const BURN_RATE := 78.0
const BEACON_BURN_RATE := 55.0
const BEACON_REACH := 27.0
const BEACON_WIDTH := 3.3
const DRAIN := 19.0
const REGEN := 8.0
const UNLOCK_AT := 30.0

var game: Node
var charge := 100.0
var focusing := false
var exhausted := false
var aim := Vector3(0, 0, 1)
## Для тестов и демонстрации: заставляет луч гореть без мыши.
var forced := false
var aim_override := Vector3.ZERO
var hits := 0
var regen_scale := 1.0
var cone: MeshInstance3D
var cone_material: StandardMaterial3D
var spot: SpotLight3D
var pivot: Node3D

func _ready() -> void:
	pivot = Node3D.new()
	pivot.name = "BeamPivot"
	add_child(pivot)
	cone = MeshInstance3D.new()
	cone.name = "FocusCone"
	var mesh := CylinderMesh.new()
	mesh.top_radius = .07
	mesh.bottom_radius = tan(HALF_ANGLE) * RANGE * .82
	mesh.height = RANGE
	mesh.radial_segments = 24
	mesh.cap_top = false
	mesh.cap_bottom = false
	cone.mesh = mesh
	cone.rotation_degrees.x = 90
	cone.position.z = -RANGE * .5
	cone_material = StandardMaterial3D.new()
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_material.albedo_color = Color(1.0, .8, .48, .18)
	cone.material_override = cone_material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(cone)
	spot = SpotLight3D.new()
	spot.name = "FocusLight"
	spot.light_color = Color("ffd89a")
	spot.spot_range = RANGE + 2
	spot.spot_angle = rad_to_deg(HALF_ANGLE) + 4
	spot.light_energy = 0
	spot.shadow_enabled = false
	pivot.add_child(spot)
	pivot.visible = false

func reset() -> void:
	charge = 100
	exhausted = false
	focusing = false
	forced = false
	aim_override = Vector3.ZERO
	if is_instance_valid(game) and is_instance_valid(game.player):
		game.player.focus_direction = Vector3.ZERO

func wants_focus(active: bool) -> bool:
	if not active or not game.player.lantern_on or game.player.fishing_pose:
		return false
	if forced:
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_physical_key_pressed(KEY_C)

func update_aim() -> void:
	if aim_override != Vector3.ZERO:
		aim = Vector3(aim_override.x, 0, aim_override.z).normalized()
		return
	if Input.is_physical_key_pressed(KEY_C) or forced or not is_instance_valid(game.camera):
		var yaw: float = game.player.get_node("Visual").rotation.y
		aim = Vector3(sin(yaw), 0, cos(yaw))
		return
	var mouse := get_viewport().get_mouse_position()
	var origin: Vector3 = game.camera.project_ray_origin(mouse)
	var normal: Vector3 = game.camera.project_ray_normal(mouse)
	var height: float = game.player.global_position.y + .2
	if absf(normal.y) < .001:
		return
	var t := (height - origin.y) / normal.y
	var point := origin + normal * t
	var flat: Vector3 = point - game.player.global_position
	flat.y = 0
	if flat.length() > .3:
		aim = flat.normalized()

func tick(delta: float, active: bool) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var wants := wants_focus(active)
	if exhausted and charge >= UNLOCK_AT:
		exhausted = false
	focusing = wants and not exhausted and charge > 0
	if focusing:
		update_aim()
		charge = maxf(0, charge - DRAIN * delta)
		if charge <= 0:
			exhausted = true
			game.notify("Фонарь перегрелся — луч остынет за несколько секунд.", 2.5)
	elif active:
		var rate := REGEN * regen_scale * (2.2 if game.is_safe(game.player.global_position) else 1.0)
		charge = minf(100, charge + rate * delta)
	game.player.focus_direction = aim if focusing else Vector3.ZERO
	_update_visuals(delta)
	hits = 0
	if not active:
		game.sound.set_burn(false)
		return
	if focusing:
		for enemy in game.enemies:
			if is_instance_valid(enemy) and in_cone(enemy.global_position):
				enemy.burn(BURN_RATE * delta)
				hits += 1
	_beacon_sweep(delta)
	game.sound.set_burn(hits > 0)

func in_cone(point: Vector3) -> bool:
	var origin: Vector3 = game.player.global_position
	var flat: Vector3 = point - origin
	flat.y = 0
	var distance := flat.length()
	if distance > RANGE or absf(point.y - origin.y) > 2.2:
		return false
	if distance < .9:
		return true
	return aim.angle_to(flat / distance) <= HALF_ANGLE

func beacon_direction() -> Vector3:
	var beam: Node3D = game.beacon.get_node("BeamPivot")
	var forward := beam.global_transform.basis.z
	forward.y = 0
	return forward.normalized()

func in_beacon_beam(point: Vector3) -> bool:
	if not game.lighthouse_on:
		return false
	var origin: Vector3 = game.beacon.global_position
	var flat: Vector3 = point - origin
	flat.y = 0
	var direction := beacon_direction()
	var along := flat.dot(direction)
	if along < 3.0 or along > BEACON_REACH:
		return false
	return (flat - direction * along).length() <= BEACON_WIDTH

func _beacon_sweep(delta: float) -> void:
	if not game.lighthouse_on or not game.is_night():
		return
	for enemy in game.enemies:
		if is_instance_valid(enemy) and in_beacon_beam(enemy.global_position):
			enemy.burn(BEACON_BURN_RATE * delta)
			hits += 1

func _update_visuals(delta: float) -> void:
	global_position = game.player.global_position + Vector3(0, .95, 0)
	pivot.visible = focusing or spot.light_energy > .05
	var target := 9.0 if focusing else 0.0
	spot.light_energy = move_toward(spot.light_energy, target, delta * 30)
	if pivot.visible and aim != Vector3.ZERO:
		pivot.global_basis = Basis.looking_at((aim + Vector3(0, -.16, 0)).normalized(), Vector3.UP)
	var flicker := .16 + sin(Time.get_ticks_msec() * .03) * .02
	cone_material.albedo_color.a = flicker * (spot.light_energy / 9.0)
	cone.visible = focusing

func save_data() -> Dictionary:
	return {"charge": charge}

func restore(data: Dictionary) -> void:
	charge = clampf(float(data.get("charge", 100.0)), 0, 100)
	exhausted = false
