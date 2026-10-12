extends CharacterBody3D
signal stepped

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 6.3
var enabled := false
var stamina := 100.0
var lantern_on := true
var movement_yaw := 0.59
var walk_clock := 0.0
var step_clock := 0.0

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if enabled:
		direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		direction.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	direction = direction.normalized().rotated(Vector3.UP, movement_yaw)
	var running := enabled and Input.is_physical_key_pressed(KEY_SHIFT) and stamina > 1 and direction.length() > 0.1
	var speed := sprint_speed if running else walk_speed
	stamina = clampf(stamina + (-18.0 if running else 12.0) * delta, 0, 100)
	velocity.x = move_toward(velocity.x, direction.x * speed, 25 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 25 * delta)
	if not is_on_floor():
		velocity.y -= 22 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	if moving:
		$Visual.rotation.y = lerp_angle($Visual.rotation.y, atan2(direction.x, direction.z), delta * 12)
		walk_clock += delta * (12 if running else 8)
		step_clock += delta
		if step_clock > (0.26 if running else 0.4):
			step_clock = 0
			stepped.emit()
	if moving:
		$WalkAnimation.speed_scale = 1.45 if running else 1.0
		if not $WalkAnimation.is_playing():
			$WalkAnimation.play("walk")
	else:
		$WalkAnimation.stop()
		for limb in [$Visual/LeftLeg, $Visual/RightLeg, $Visual/LeftArm, $Visual/RightArm]:
			limb.rotation.x = 0
	$Visual.position.y = absf(sin(walk_clock * 2)) * 0.035 if moving else 0
	$HandLantern.visible = lantern_on
	$Visual/RightArm/LanternRig/LanternGlass.visible = lantern_on

func toggle_lantern() -> void:
	lantern_on = not lantern_on
