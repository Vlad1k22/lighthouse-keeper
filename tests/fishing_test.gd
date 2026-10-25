extends SceneTree
const Fishing = preload("res://scripts/fishing.gd")
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

func reach_bite(model) -> void:
	while model.phase == Fishing.Phase.WAITING:
		model.advance(0.1, false)

func reel_in(model, step: float = 1.0 / 60.0) -> bool:
	for frame in int(40.0 / step):
		model.advance(step, model.bar_position + model.bar_velocity * 0.22 < model.fish_position)
		if model.phase == Fishing.Phase.RESULT:
			return model.caught
	return false

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func model_checks() -> void:
	var model = Fishing.new()
	model.begin(17)
	check(model.phase == Fishing.Phase.WAITING and str(model.fish.name) == "Морской окунь", "First cast starts with an approachable fish")
	model.press_action()
	check(model.phase == Fishing.Phase.WAITING, "Early click does not hook or award a fish")
	reach_bite(model)
	check(model.phase == Fishing.Phase.BITE, "Waiting produces a limited bite window")
	model.press_action()
	check(model.phase == Fishing.Phase.REELING, "Hooking during a bite starts reeling")
	var initial: float = model.bar_position
	for i in 20:
		model.advance(0.01, true)
	check(model.bar_position > initial, "Holding the control raises the fishing bar")
	for i in 60:
		model.advance(0.01, false)
	check(model.bar_velocity <= 0.02, "Releasing control drops the fishing bar")
	model.fish_position = 0.5
	model.fish_target = 0.5
	model.target_time = 10
	model.bar_position = 0.5
	model.bar_velocity = 0
	model.progress = 0.5
	model.advance(0.01, false)
	check(model.progress > 0.5, "Keeping the fish in the zone builds catch progress")
	model.bar_position = 0.16
	model.fish_position = 0.85
	model.fish_target = 0.85
	model.bar_velocity = 0
	model.progress = 0.5
	model.advance(0.01, false)
	check(model.progress < 0.5, "Losing the fish from the zone reduces catch progress")
	model.fish.speed = 0
	for frame in 600:
		model.advance(1.0 / 60.0, false)
		if model.phase == Fishing.Phase.RESULT:
			break
	check(model.phase == Fishing.Phase.RESULT and not model.caught, "An empty catch meter lets the fish escape")
	model.begin(18)
	reach_bite(model)
	model.advance(3.1, false)
	check(model.phase == Fishing.Phase.RESULT and not model.caught, "Missed bite ends without an automatic catch")
	model.close()
	check(not model.is_open(), "A failed cast can be closed and retried")
	var balanced := true
	var bounded := true
	var species := {}
	for index in 18:
		model.begin(index + 50, str(Fishing.FISH[index % 3].id))
		species[str(model.fish.name)] = true
		reach_bite(model)
		model.press_action()
		balanced = reel_in(model, [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0][index % 3]) and balanced
		bounded = bounded and model.bar_position >= model.bar_size * 0.5 and model.bar_position <= 1.0 - model.bar_size * 0.5 and model.progress >= 0 and model.progress <= 1
	check(balanced, "All species can be caught by tracking at 30, 60 and 144 FPS")
	check(bounded and species.size() == 3, "Three fish species keep the bar and progress within bounds")
	var result_weight: int = model.weight
	model.advance(10, true)
	model.finish(true, "duplicate")
	check(model.weight == result_weight and model.phase == Fishing.Phase.RESULT, "Completed catch remains stable until dismissed")

func run() -> void:
	model_checks()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_shift()
	game.save_path = "user://automated_fishing_test.json"
	var dock: Area3D = game.world.get_node("Station_fish")
	check(not game.attempt_interaction(dock), "Fishing cannot start away from the dock")
	game.player.position = dock.position + Vector3(0, 0.3, 0)
	game.player.velocity = Vector3.ZERO
	# Сначала дать телу опуститься на доски причала после тестовой телепортации.
	for frame in 20:
		await physics_frame
	game.fish_items.append(game.PROVISIONS.fish_item("perch", 300))
	game.fish_items.append(game.PROVISIONS.fish_item("perch", 400))
	game.sync_provisions()
	game.hour = 22
	game.was_night = false
	game.spawn_shadow(game.player.position + Vector3(0, 0, 1))
	var enemy = game.enemies[0]
	game.player.lantern_on = false
	var old_enemy_position: Vector3 = enemy.position
	var old_hour: float = game.hour
	var old_hunger: float = game.hunger
	check(game.attempt_interaction(dock), "Dock interaction starts fishing")
	var old_player_xz := Vector2(game.player.position.x, game.player.position.z)
	var move := InputEventKey.new()
	move.physical_keycode = KEY_W
	move.pressed = true
	Input.parse_input_event(move)
	await create_timer(0.25).timeout
	move.pressed = false
	Input.parse_input_event(move)
	check(game.hud.fishing_overlay.visible and not game.player.enabled, "Fishing overlay opens and disables walking")
	check(Vector2(game.player.position.x, game.player.position.z).distance_to(old_player_xz) < 0.01, "WASD cannot move player off the pier during fishing")
	check(game.hour == old_hour and game.hunger == old_hunger and game.health == 100, "Island clock, survival and damage freeze during fishing")
	check(enemy.position.is_equal_approx(old_enemy_position), "Enemies remain frozen during fishing")
	check(not game.save_game() and not game.load_game() and not game.attempt_interaction(dock), "Saving, loading and repeated casts are blocked during fishing")
	await key(KEY_J)
	check(not game.journal_open and not game.paused, "Journal shortcut does not interrupt fishing")
	await key(KEY_ESCAPE)
	check(not game.fishing.is_open() and game.player.enabled and not game.paused and game.inventory.fish == 2, "Escape cancels without a reward or opening the pause menu")
	game.clear_enemies()
	game.player.lantern_on = true
	game.hour = 17
	game.was_night = false
	game.hours_per_second = 0
	game.attempt_interaction(dock)
	reach_bite(game.fishing)
	game.fishing.advance(3.1, false)
	check(not game.fishing.caught and game.inventory.fish == 2, "Failed cast leaves the inventory unchanged")
	game.fishing.advance(0.5, false)
	var casts_before: int = game.fishing.casts
	await key(KEY_E)
	check(not game.fishing.is_open() and game.fishing.casts == casts_before, "Closing result with E does not immediately cast again")
	game.attempt_interaction(dock)
	reach_bite(game.fishing)
	await key(KEY_SPACE)
	check(game.fishing.phase == Fishing.Phase.REELING, "Physical Space key hooks the fish")
	check(reel_in(game.fishing) and game.inventory.fish == 3, "Successful catch adds exactly one fish")
	game.fishing.finish(true, "duplicate")
	check(game.inventory.fish == 3, "Repeated completion cannot duplicate the catch")
	game.fishing.advance(0.5, false)
	await key(KEY_E)
	check(game.player.enabled and not game.hud.fishing_overlay.visible, "Closing catch result restores normal gameplay")
	game.attempt_interaction(dock)
	reach_bite(game.fishing)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var bar_before: float = game.fishing.bar_position
	Input.parse_input_event(click)
	await create_timer(0.25).timeout
	check(game.fishing.phase == Fishing.Phase.REELING and game.fishing.bar_position > bar_before, "Holding the left mouse button hooks and raises the bar")
	click.pressed = false
	Input.parse_input_event(click)
	await create_timer(0.4).timeout
	check(game.fishing.bar_velocity < 0, "Releasing the mouse lets the bar fall")
	game.close_fishing()
	check(game.save_game(), "Catch can be saved after leaving the minigame")
	game.fish_items.clear()
	game.sync_provisions()
	check(game.load_game() and game.inventory.fish == 3 and not game.fishing.is_open(), "Save restores caught fish without reopening fishing")
	print("RESULT: ", checks - failures, "/", checks, " fishing checks passed")
	game.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
