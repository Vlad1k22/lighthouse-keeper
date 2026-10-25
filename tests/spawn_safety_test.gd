extends SceneTree
## Реальная физика новой смены и возврата на сушу после падения в воду.
var game: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hours_per_second = 0
	game.start_shift()
	for frame in 180:
		await physics_frame
	check(game.player.is_on_floor(), "New shift spawns on solid ground")
	check(game.player.position.y > 0.8 and game.player.position.y < 1.4, "Player stays on the island after three seconds")
	check(game.health == 100 and not game.finished, "Standing at spawn does not cause water damage")
	game.player.position = Vector3(50, -3, 50)
	game.player.velocity = Vector3.ZERO
	for frame in 180:
		await physics_frame
	check(game.player.is_on_floor(), "Water recovery returns player to solid ground")
	check(game.player.position.distance_to(Vector3(3, 1, 4)) < 0.5, "Water recovery returns to the cabin spawn")
	check(game.health == 90 and not game.finished, "Water recovery applies damage once without a death loop")
	print("RESULT: ", checks - failures, "/", checks, " spawn checks passed")
	game.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
