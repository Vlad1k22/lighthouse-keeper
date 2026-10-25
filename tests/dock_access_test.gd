extends SceneTree
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func walk_to(target_x: float, code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	for frame in 240:
		await physics_frame
		if (code == KEY_A and game.player.position.x <= target_x) or (code == KEY_D and game.player.position.x >= target_x):
			break
	key.pressed = false
	Input.parse_input_event(key)
	for frame in 12:
		await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_shift()
	game.hours_per_second = 0
	game.player.movement_yaw = 0
	for lane in [5.0, 5.4]:
		game.player.position = Vector3(23.3, 1.3, lane)
		game.player.velocity = Vector3.ZERO
		for frame in 30:
			await physics_frame
		check(game.player.is_on_floor(), "Player stands on fishing dock, lane " + str(lane))
		await walk_to(17.5, KEY_A)
		check(game.player.position.x < 18.0, "Player can walk from dock onto island without jumping")
		check(game.health == 100 and game.player.is_on_floor(), "Dock exit keeps player supported without water damage")
		await walk_to(23.3, KEY_D)
		check(game.player.position.x > 23.0, "Player can return from island to fishing spot")
		check(game.health == 100 and game.player.is_on_floor(), "Round trip has no falls or collision traps")
	print("RESULT: ", checks - failures, "/", checks, " dock checks passed; position=", game.player.position)
	game.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
