extends SceneTree

const INTERIOR = preload("res://scripts/lighthouse_interior.gd")
const DIRECTIONS := [
	[KEY_S], [KEY_S, KEY_D], [KEY_D], [KEY_D, KEY_W],
	[KEY_W], [KEY_W, KEY_A], [KEY_A], [KEY_A, KEY_S],
]
var game: Node3D
var player: CharacterBody3D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)

func move_with(keys: Array) -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		if Input.is_physical_key_pressed(code) != (code in keys):
			key(code, code in keys)

# Follow the staircase with the same eight WASD directions available to players.
func walk_to(target: Vector3) -> bool:
	for i in range(75):
		var remaining := INTERIOR.ORIGIN + target - player.position
		if Vector2(remaining.x, remaining.z).length() < .095:
			return true
		var angle: float = atan2(remaining.x, remaining.z) - player.movement_yaw
		move_with(DIRECTIONS[posmod(roundi(angle/(TAU/8)), 8)])
		await physics_frame
	move_with([])
	print("Blocked at ", player.position - INTERIOR.ORIGIN, " on the way to ", target)
	return false

func traverse(from_step: int, to_step: int, direction: int) -> bool:
	for step in range(from_step, to_step, direction):
		var target := INTERIOR.polar(1.52, step * TAU / 24, 0)
		if not await walk_to(target):
			return false
		var expected := clampf(INTERIOR.PITCH*step/24, 0, INTERIOR.TOP)
		if absf(player.position.y - INTERIOR.ORIGIN.y - expected) > .24:
			move_with([])
			print("Unexpected height at step ", step, ": ", player.position - INTERIOR.ORIGIN, " expected ", expected)
			return false
	return true

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	player = game.player
	player.position = INTERIOR.OUTSIDE_DOOR
	player.reset_motion()
	await frames(18)
	check(game.lighthouse_interior.near_door(player.position) and player.is_on_floor(), "Outside door is reachable on dry ground")
	await tap(KEY_E)
	await frames(24)
	var room = game.lighthouse_interior
	check(room.active and player.is_on_floor(), "E enters the service bay")
	if not room.active:
		quit(1)
		return
	check(room.walls.size() == 64 and room.flights.size() == 36 and room.optic is MeshInstance3D, "Imported mesh groups include the complete stairs, walls and optic")
	check(not room.walls[2].visible and room.walls[10].visible and not room.deck.visible, "Camera hides the near wall and the deck above the keeper")
	check(game.camera.environment == room.room_env and absf(game.camera.size - INTERIOR.ZOOM) < .02 and game.map_player_position() == INTERIOR.OUTSIDE_DOOR, "Close camera uses the room lighting; map stays on the island")
	var ascended := await traverse(-1, 76, 1)
	move_with([])
	await frames(10)
	check(ascended and player.is_on_floor() and absf(player.position.y-INTERIOR.ORIGIN.y-INTERIOR.TOP) < .05, "Keeper walks up all three turns without jumping")
	if not ascended:
		quit(1)
		return
	check(room.deck.visible and room.optic.visible and not room.glow.visible, "Unpowered optic is visible on the upper landing")
	await tap(KEY_E)
	check(game.message.contains("генератора"), "The optic inspection describes the existing power circuit")
	game.lighthouse_on = true
	await process_frame
	var first_angle: float = room.rotor.rotation.y
	await process_frame
	await process_frame
	check(room.glow.visible and room.beacon_light.visible and not is_equal_approx(room.rotor.rotation.y,first_angle), "The room optic lights up and follows the rotating beacon")
	game.save_path = "user://automated_lighthouse_interior.json"
	var saved_at := player.position
	check(game.save_game(true), "Interior position can be saved")
	game.start_shift()
	check(not room.active and game.world.visible, "A new shift restores the outside camera")
	check(game.load_game() and room.active and player.position == saved_at, "Reload restores the same floor and the interior camera")
	DirAccess.remove_absolute(game.save_path)
	await frames(12)
	var descended := await traverse(74, -2, -1)
	move_with([])
	await frames(12)
	check(descended and player.is_on_floor() and player.position.y - INTERIOR.ORIGIN.y < .05, "Keeper walks down to the service bay")
	await tap(KEY_E)
	await frames(24)
	check(not room.active and game.camera.environment == null and game.world.visible and player.is_on_floor(), "E exits to the dry doorway and restores the island camera")
	print("LIGHTHOUSE INTERIOR: %d/%d" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
