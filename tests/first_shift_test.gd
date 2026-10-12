extends SceneTree
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

func station(id: String) -> Area3D:
	for item in game.stations:
		if item.station_id == id:
			return item
	return null

func interact(id: String) -> bool:
	var item := station(id)
	game.player.position = item.position + Vector3(0, 0.3, 1.0)
	game.player.velocity = Vector3.ZERO
	return game.attempt_interaction(item)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hours_per_second = 0
	game.save_path = "user://automated_first_shift_test.json"
	game.start_shift()
	check(game.stations.size() == 9, "All nine Area3D interaction stations exist")
	check(not game.attempt_interaction(station("fuel")), "Distant resource cannot be picked up")
	check(not interact("beacon"), "Lighthouse requires fuel")
	check(interact("fuel") and game.inventory.fuel == 1, "Fuel pickup enters inventory")
	check(not interact("fuel") and game.inventory.fuel == 1, "Fuel cannot be collected twice")
	check(interact("beacon") and game.lighthouse_on and game.inventory.fuel == 0, "Generator consumes fuel and powers lighthouse")
	check(not interact("workbench"), "Barricade cannot be built without wood")
	for index in 3:
		interact("wood")
	check(game.inventory.wood == 3 and station("wood").remaining == 6, "Wood collection updates stock and inventory")
	check(interact("workbench") and game.barricade_built and game.inventory.wood == 0, "Barricade consumes three wood and creates geometry")
	check(game.is_safe(Vector3(5, 1, 3)) and game.is_safe(Vector3(-9, 1, -4)), "Cabin and beacon create safe areas")
	check(not game.is_safe(Vector3(14, 1, 8)), "Forest remains dangerous at night")
	check(interact("fish") and game.busy_time > 0 and not game.player.enabled, "Fishing starts timed action")
	game.busy_time = 0.001
	await create_timer(0.05).timeout
	check(game.inventory.fish == 1 and game.player.enabled, "Fishing finishes with one fish")
	check(interact("cook") and game.inventory.fish == 0 and game.inventory.food == 2, "Cooking converts fish to food")
	game.hunger = 20
	check(game.eat() and game.hunger == 55, "Food restores hunger and consumes item")
	check(interact("note") and game.journal_open and game.paused and not game.player.enabled, "Reading a discovery pauses gameplay")
	check(game.journal_entries == ["sign"] and game.hud.reader.visible, "Sign unlocks a readable journal entry")
	var close_key := InputEventKey.new()
	close_key.physical_keycode = KEY_E
	close_key.pressed = true
	Input.parse_input_event(close_key)
	await process_frame
	close_key.pressed = false
	Input.parse_input_event(close_key)
	check(not game.journal_open and not game.paused and game.player.enabled, "E closes the journal and restores controls")
	interact("radio")
	game.close_journal()
	interact("radio")
	game.close_journal()
	check(game.journal_entries.size() == 2, "Radio adds a second story without duplicate discoveries")
	game.coastal_life.weather_mode = 1
	await create_timer(0.2).timeout
	check(game.coastal_life.rain_strength > 0.04 and game.coastal_life.get_node("Rain").emitting, "Rain ramps up and emits particles")
	game.coastal_life.weather_mode = 2
	await create_timer(0.3).timeout
	check(game.coastal_life.rain_strength < 0.02, "Clear weather smoothly stops the rain")
	game.inventory.wood = 2
	game.hour = 22
	check(game.save_game(), "Save file can be written")
	game.inventory.wood = 0
	game.health = 5
	check(game.load_game() and game.inventory.wood == 2 and game.health == 100 and game.barricade_built, "Load restores resources, health and world state")
	check(game.journal_entries.size() == 2 and game.coastal_life.weather_mode == 2, "Save restores discoveries and chosen weather")
	await create_timer(0.05).timeout
	check(game.enemies.size() == 3, "Night spawns three shadow enemies")
	game.clear_enemies()
	game.player.position = Vector3(-3, 1.2, 3)
	game.player.lantern_on = true
	game.spawn_shadow(Vector3(-3, 1.2, 3.8))
	await create_timer(0.2).timeout
	check(game.health == 100, "Hand lantern repels nearby shadow")
	var enemy: CharacterBody3D = game.enemies[0]
	game.player.lantern_on = false
	enemy.position = game.player.position + Vector3(0, 0, 0.7)
	enemy.attack_cooldown = 0
	await create_timer(0.1).timeout
	check(game.health < 100, "Unprotected player takes damage")
	game.paused = true
	var old_position := enemy.position
	await create_timer(0.1).timeout
	check(enemy.position.is_equal_approx(old_position), "Enemies stop while paused")
	game.paused = false
	game.clear_enemies()
	game.hour = 17
	game.was_night = false
	game.player.position = Vector3(0, 1.2, 2)
	var initial_position: Vector3 = game.player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.5).timeout
	check(game.player.get_node("WalkAnimation").is_playing(), "AnimationPlayer plays the walking animation")
	key.pressed = false
	Input.parse_input_event(key)
	check(game.player.position.distance_to(initial_position) > 1.0, "WASD moves CharacterBody3D using physics")
	check(game.player.position.y > 0.8 and game.player.position.y < 1.4, "Island collision supports player")
	game.hour = 6.1
	game.was_night = true
	await process_frame
	await process_frame
	check(game.finished and game.hud.menu.visible, "Prepared player reaches first dawn victory")
	print("RESULT: ", checks - failures, "/", checks, " checks passed")
	game.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
