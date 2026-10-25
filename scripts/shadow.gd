extends CharacterBody3D
## Преследование, обход препятствия и отступление от света.
var keeper: CharacterBody3D
var game: Node
var attack_cooldown := 0.0
var life_clock := 0.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(keeper) or not is_instance_valid(game):
		return
	if not game.playing or game.finished or game.paused or game.fishing.is_open():
		return
	life_clock += delta
	attack_cooldown -= delta
	var offset := keeper.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	var direction := offset.normalized()
	var afraid: bool = game.is_safe(global_position) or (keeper.lantern_on and distance < 5.2)
	if afraid:
		direction = -direction
	elif distance > 17:
		direction = Vector3(sin(life_clock * 0.5), 0, cos(life_clock * 0.5))
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.7, global_position + Vector3.UP * 0.7 + direction * 1.8, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		direction = direction.rotated(Vector3.UP, 1.2)
	var speed := 2.4 if afraid else 1.65
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= delta * 20
	move_and_slide()
	$Visual.rotation.y = atan2(direction.x, direction.z)
	$Visual.scale.y = 1.0 + sin(life_clock * 2.5) * 0.04
	if distance < 1.3 and not afraid and attack_cooldown <= 0:
		game.take_damage(12)
		attack_cooldown = 1.5
	if global_position.y < -4 or Vector2(global_position.x, global_position.z).length() > 32:
		queue_free()
