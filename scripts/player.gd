extends CharacterBody3D
signal stepped

const VISUAL = preload("res://scripts/character_visual.gd")
const MOTION = preload("res://scripts/character_motion.gd")
const JUMP_COST := 18.0
const JUMP_SPEED := 5.1
const AIR_SPEED := 4.45
const LAND_TIME := .19
const GRAVITY := 22.0

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 6.3
var enabled := false
var indoors := false
var stamina := 100.0
var lantern_on := true
var movement_yaw := 0.59
var step_clock := 0.0
var jump_requested := false
var jump_in_progress := false
var air_time := 0.0
var landing_time := 0.0
var stamina_delay := 0.0
var gesture := ""
var gesture_time := 0.0
var fishing_pose := false
var motion := MOTION.new()
var lantern_socket: BoneAttachment3D

var stamina_recovery_scale := 1.0

func _ready() -> void:
	motion.bind(VISUAL.install($Visual, "keeper"))
	if motion.skeleton != null and motion.skeleton.find_bone("Lantern") >= 0:
		lantern_socket = BoneAttachment3D.new()
		lantern_socket.name = "HandLanternSocket"
		motion.skeleton.add_child(lantern_socket)
		lantern_socket.bone_name = "Lantern"
	motion.play("idle", 0)
	motion.tick(0)
	_sync_lantern()

func request_jump() -> void:
	if enabled:
		jump_requested = true

func reset_motion() -> void:
	velocity = Vector3.ZERO
	jump_requested = false
	jump_in_progress = false
	air_time = 0
	landing_time = 0
	stamina_delay = 0
	step_clock = 0
	fishing_pose = false
	gesture = ""
	gesture_time = 0
	motion.play("idle", 0, true)

func play_gesture(clip: String, duration: float = .55) -> void:
	if jump_in_progress:
		return
	gesture = clip
	gesture_time = motion.length(clip, duration)
	motion.play(clip, .07, true)

func set_fishing_pose(value: bool) -> void:
	fishing_pose = value
	if value:
		play_gesture("cast", .67)
	elif gesture == "cast":
		gesture_time = 0

func _sync_lantern() -> void:
	$HandLantern.visible = lantern_on
	if is_instance_valid(lantern_socket):
		$HandLantern.global_position = lantern_socket.global_position
	if is_instance_valid(motion.lantern_glow):
		motion.lantern_glow.visible = lantern_on
	elif has_node("Visual/RightArm/LanternRig/LanternGlass"):
		$Visual/RightArm/LanternRig/LanternGlass.visible = lantern_on

func _physics_process(delta: float) -> void:
	if not enabled:
		jump_requested = false
		if fishing_pose:
			gesture_time = maxf(0, gesture_time-delta)
			if gesture_time <= 0:
				motion.play("fish_hold")
			motion.tick(delta)
		_sync_lantern()
		return
	var direction := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	direction = direction.normalized().rotated(Vector3.UP, movement_yaw)
	var grounded := is_on_floor()
	landing_time = maxf(0, landing_time-delta)
	stamina_delay = maxf(0, stamina_delay-delta)
	gesture_time = maxf(0, gesture_time-delta)
	var launched := jump_requested and not indoors and grounded and landing_time <= 0 and stamina >= JUMP_COST
	jump_requested = false
	if launched:
		stamina -= JUMP_COST
		stamina_delay = .72
		jump_in_progress = true
		air_time = 0
		gesture_time = 0
		velocity.y = JUMP_SPEED
		motion.play("jump", .055, true)
	var running := not indoors and grounded and not launched and landing_time <= 0 and Input.is_physical_key_pressed(KEY_SHIFT) and stamina > 1 and direction.length_squared() > .01
	var speed := 2.35 if indoors else (sprint_speed if running else walk_speed)
	if running:
		stamina = maxf(0, stamina-18.0*delta)
	elif grounded and stamina_delay <= 0:
		stamina = minf(100, stamina+12.0*stamina_recovery_scale*delta)
	if landing_time > 0:
		speed *= .60
	var airborne := not grounded or launched
	var acceleration := 10.0 if airborne else 25.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if airborne:
		var plane := Vector2(velocity.x,velocity.z).limit_length(AIR_SPEED)
		velocity.x = plane.x
		velocity.z = plane.y
		if not launched:
			velocity.y -= GRAVITY * delta
	elif grounded:
		velocity.y = -.1
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	if direction.length_squared() > .01:
		$Visual.rotation.y = lerp_angle($Visual.rotation.y, atan2(direction.x, direction.z), minf(1,delta*12))
	if not is_on_floor():
		air_time += delta
		step_clock = 0
		motion.play("jump" if jump_in_progress and velocity.y > 0 else "fall", .08)
	elif air_time > .105:
		jump_in_progress = false
		air_time = 0
		landing_time = LAND_TIME
		step_clock = 0
		motion.play("land", .06, true)
		stepped.emit()
	else:
		jump_in_progress = false
		air_time = 0
		if landing_time <= 0 and gesture_time <= 0:
			motion.play(("run" if running else "walk") if moving else "idle")
	if is_on_floor() and moving and landing_time <= 0:
		step_clock += delta
		if step_clock > (0.26 if running else 0.4):
			step_clock = 0
			stepped.emit()
	motion.tick(delta)
	_sync_lantern()

func toggle_lantern() -> void:
	lantern_on = not lantern_on
	play_gesture("lantern")
	_sync_lantern()
