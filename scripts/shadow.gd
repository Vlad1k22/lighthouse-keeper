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

func _ready() -> void:
	motion.bind(VISUAL.install($Visual, kind))
	motion.play("idle", 0)
	motion.tick(0)

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
	attack_cooldown -= delta
	var offset := keeper.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	var direction := offset.normalized()
	var afraid: bool = game.is_safe(global_position) or (keeper.lantern_on and distance < 5.2)
	var in_reach := distance < (1.48 if kind == "drowned" else 1.30) and absf(keeper.global_position.y-global_position.y) < .92
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
		direction = -direction
	elif distance > 17:
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
	if mirroring:
		direction = Vector3(-keeper.velocity.x,0,keeper.velocity.z).normalized()
		speed = Vector2(keeper.velocity.x,keeper.velocity.z).length()*.8
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= delta * 20
	move_and_slide()
	var facing := offset.normalized() if attack_time > 0 or recoil_time > 0 else direction
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
