extends CharacterBody3D
## Преследование, обход препятствия и отступление от света.
const VISUAL = preload("res://scripts/character_visual.gd")
const MOTION = preload("res://scripts/character_motion.gd")
var keeper: CharacterBody3D
var game: Node
var kind := "shadow"
var attack_cooldown := 0.0
var attack_time := 0.0
var windup := 0.0
var recoil_time := 0.0
var was_afraid := false
var life_clock := 0.0
var passive := false
var stationary := false
var mirroring := false
var motion := MOTION.new()
## Тьма — «щит» тени. Луч фонаря и маяка выжигает её, после чего тень рассеивается.
var max_darkness := 100.0
var darkness := 100.0
var burn_glow := 0.0
var dissolving := 0.0
## Пустая цель — охота на смотрителя; "generator" / "barricade" — ночная вылазка к источнику света.
var goal := ""
var goal_point := Vector3.ZERO
var sabotage := 0.0
var phantom := false
var day_event := false
var burn_light: OmniLight3D
var darkness_bar: Node3D
var darkness_fill: MeshInstance3D

func _ready() -> void:
	motion.bind(VISUAL.install($Visual, kind))
	motion.play("idle", 0)
	motion.tick(0)

func burn(amount: float) -> void:
	if dissolving > 0 or amount <= 0:
		return
	darkness = maxf(0, darkness-amount)
	burn_glow = .22
	if darkness <= 0:
		dissolve()

func is_dissolving() -> bool:
	return dissolving > 0

func dissolve() -> void:
	if dissolving > 0:
		return
	dissolving = .001
	collision_layer = 0
	collision_mask = 1
	attack_time = 0
	windup = 0
	motion.play("recoil",.05,true)
	if is_instance_valid(game) and game.has_method("on_shadow_dispelled"):
		game.on_shadow_dispelled(self)

func _update_burn_visuals(delta: float) -> void:
	burn_glow = maxf(0, burn_glow-delta)
	if burn_glow > 0 and not is_instance_valid(burn_light):
		burn_light = OmniLight3D.new()
		burn_light.name = "BurnGlow"
		burn_light.position = Vector3(0, 1.0, 0)
		burn_light.light_color = Color("ff9a3c")
		burn_light.omni_range = 3.6
		add_child(burn_light)
	if is_instance_valid(burn_light):
		burn_light.light_energy = (burn_glow/.22)*(3.4+sin(life_clock*40.0)*.9) + (3.0 if dissolving > 0 else 0.0)*(1.0-minf(1,dissolving/.7))
	if burn_glow > 0 and dissolving <= 0:
		$Visual.position.x = sin(life_clock*70.0)*.045
	else:
		$Visual.position.x = 0
	var hurt := darkness < max_darkness and dissolving <= 0
	if hurt and not is_instance_valid(darkness_bar):
		_build_darkness_bar()
	if is_instance_valid(darkness_bar):
		darkness_bar.visible = hurt
		darkness_fill.scale.x = maxf(.02, darkness/max_darkness)

func _bar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.render_priority = 2
	return material

func _build_darkness_bar() -> void:
	darkness_bar = Node3D.new()
	darkness_bar.name = "DarknessBar"
	darkness_bar.position = Vector3(0, 2.35, 0)
	add_child(darkness_bar)
	var back := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(.92, .12)
	back.mesh = back_mesh
	back.material_override = _bar_material(Color(.03,.05,.07,.8))
	darkness_bar.add_child(back)
	darkness_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(.84, .07)
	darkness_fill.mesh = fill_mesh
	var fill_material := _bar_material(Color("6f4bd8"))
	fill_material.render_priority = 3
	darkness_fill.material_override = fill_material
	darkness_bar.add_child(darkness_fill)

func _process_dissolve(delta: float) -> void:
	dissolving += delta
	var t := minf(1, dissolving/.7)
	$Visual.scale = Vector3.ONE*(1.0-t*.85)
	$Visual.position.y = -t*.9
	velocity = Vector3.ZERO
	motion.tick(delta)
	_update_burn_visuals(delta)
	if dissolving >= .7:
		queue_free()

func begin_attack() -> void:
	attack_time = motion.length("attack", .93 if kind == "drowned" else .73)
	windup = .53 if kind == "drowned" else .30
	attack_cooldown = 1.5
	motion.play("attack", .08, true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(keeper) or not is_instance_valid(game):
		return
	if not game.playing or game.finished or game.paused or game.fishing.is_open() or game.expedition.sailing:
		return
	life_clock += delta
	if dissolving > 0:
		_process_dissolve(delta)
		return
	_update_burn_visuals(delta)
	attack_cooldown -= delta
	var to_keeper := keeper.global_position - global_position
	to_keeper.y = 0
	var keeper_distance := to_keeper.length()
	# Диверсант идёт к своей цели, но бросается на смотрителя, если тот подошёл без света.
	var raiding: bool = not goal.is_empty() and not (keeper_distance < 2.6 and not keeper.lantern_on)
	var offset := (goal_point - global_position) if raiding else to_keeper
	offset.y = 0
	var distance := offset.length()
	var direction := offset.normalized()
	var afraid: bool = (not raiding and game.is_safe(global_position)) or (keeper.lantern_on and keeper_distance < (3.2 if raiding else 5.2))
	var in_reach := keeper_distance < (1.48 if kind == "drowned" else 1.30) and absf(keeper.global_position.y-global_position.y) < .92
	var can_hit: bool = in_reach and not game.is_safe(keeper.global_position) and not afraid and not passive
	recoil_time = maxf(0, recoil_time-delta)
	if afraid and (not was_afraid or attack_time > 0):
		attack_time = 0
		windup = 0
		if not mirroring:
			recoil_time = motion.length("recoil",.5)
			motion.play("recoil",.08,true)
	was_afraid = afraid
	if attack_time > 0:
		attack_time = maxf(0,attack_time-delta)
		if windup > 0:
			windup = maxf(0,windup-delta)
			if windup <= 0 and can_hit:
				game.take_damage(12 + mini(8, game.day/4) + (5 if kind == "drowned" else 0))
	elif attack_cooldown <= 0 and can_hit:
		begin_attack()
	if afraid:
		direction = -to_keeper.normalized() if keeper.lantern_on and keeper_distance < 5.2 else -direction
	elif distance > 17 and not raiding:
		direction = Vector3(sin(life_clock * 0.5), 0, cos(life_clock * 0.5))
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.7, global_position + Vector3.UP * 0.7 + direction * 1.8, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		direction = direction.rotated(Vector3.UP, 1.2)
	var speed := 2.4 if afraid else 1.65 + minf(0.65, (game.day-1)*0.035)
	if kind == "drowned":
		speed *= .77
	if attack_time > 0:
		speed = 0
	if stationary and distance>4:speed=0
	var at_goal: bool = raiding and not afraid and distance < 1.7
	if at_goal:
		speed = 0
		sabotage += delta
		if attack_time <= 0 and attack_cooldown <= 0:
			attack_time = motion.length("attack", .73)
			attack_cooldown = 1.1
			motion.play("attack", .08, true)
		if game.has_method("on_shadow_sabotage"):
			game.on_shadow_sabotage(self, delta)
	if mirroring:
		direction = Vector3(-keeper.velocity.x,0,keeper.velocity.z).normalized()
		speed = Vector2(keeper.velocity.x,keeper.velocity.z).length()*.8
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= delta * 20
	move_and_slide()
	var facing := (offset.normalized() if raiding else to_keeper.normalized()) if attack_time > 0 or recoil_time > 0 else direction
	if facing.length_squared() > .01:
		$Visual.rotation.y = lerp_angle($Visual.rotation.y, atan2(facing.x, facing.z), minf(1,delta*13))
	if mirroring:
		var pose: String = keeper.motion.current
		motion.play(pose if pose in ["walk","run","jump","fall","land","lantern"] else "idle")
		if is_instance_valid(motion.lantern_glow):
			motion.lantern_glow.visible = keeper.lantern_on
	elif attack_time <= 0 and recoil_time <= 0:
		motion.play(("run" if afraid else "walk") if Vector2(velocity.x,velocity.z).length() > .15 else "watch" if stationary else "idle")
	motion.tick(delta)
	if passive and life_clock>10:queue_free()
	if global_position.y < -4 or Vector2(global_position.x, global_position.z).length() > 65:
		queue_free()
