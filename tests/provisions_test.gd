extends SceneTree
const Food = preload("res://scripts/provisions.gd")
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func catch_fish(id: String) -> bool:
	game.start_fishing()
	game.fishing.begin(45, id)
	game.fishing.advance(3, false)
	game.fishing.press_action()
	for frame in 3600:
		var f = game.fishing
		f.advance(1.0 / 60.0, f.bar_position + f.bar_velocity * 0.22 < f.fish_position)
		if f.phase == game.FISHING.Phase.RESULT:
			break
	var success: bool = game.fishing.caught
	game.close_fishing()
	return success

func run() -> void:
	var common := Food.bonuses(Food.fish_item("perch", 500))
	var rare := Food.bonuses(Food.fish_item("mackerel", 1000))
	var legendary := Food.bonuses(Food.fish_item("sturgeon", 3000))
	check(common.health == 7 and common.hunger == 20, "Common 500 g fish restores 7 health and 20 hunger")
	check(rare.health == 16 and rare.hunger == 37, "Rare 1000 g fish restores 16 health and 37 hunger")
	check(legendary.health == 42 and legendary.hunger == 81, "Legendary 3000 g fish restores 42 health and 81 hunger")
	var heavier := Food.bonuses(Food.fish_item("perch", 700))
	check(heavier.health > common.health and heavier.hunger > common.hunger, "Heavier fish of the same type has higher nutrition")
	var same_weight_rare := Food.bonuses(Food.fish_item("mackerel", 500))
	var same_weight_legendary := Food.bonuses(Food.fish_item("sturgeon", 500))
	check(same_weight_rare.health > common.health and same_weight_legendary.health > same_weight_rare.health and same_weight_rare.hunger > common.hunger and same_weight_legendary.hunger > same_weight_rare.hunger, "Rarity increases both bonuses independently of weight")
	var rng := RandomNumberGenerator.new()
	rng.seed = 125
	var counts := {"common": 0, "rare": 0, "legendary": 0}
	for i in 10000:
		counts[Food.choose(rng, false).rarity] += 1
	check(counts.common > 6500 and counts.common < 7500 and counts.rare > 2000 and counts.rare < 3000 and counts.legendary > 300 and counts.legendary < 700, "Catch rarity follows approximately 70/25/5 distribution")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_shift()
	game.hours_per_second = 0
	game.save_path = "user://automated_provisions_test.json"
	for id in ["perch", "mackerel", "sturgeon"]:
		check(catch_fish(id), "Full minigame can award species " + id)
	check(game.fish_items.size() == 3 and game.fish_items[2].rarity == "legendary" and game.fish_items[2].weight >= 1200, "Catches retain individual rarity and generated weight")
	game.selected_fish = 1
	game.select_provision(false)
	check(game.selected_fish == 2, "Player can select which fish to cook")
	var original: Dictionary = game.fish_items[2].duplicate(true)
	var stove: Area3D = game.world.get_node("Station_cook")
	game.player.position = stove.position + Vector3(0, 0.3, 1)
	game.player.velocity = Vector3.ZERO
	check(game.attempt_interaction(stove) and game.food_items[game.selected_food] == original and game.inventory.fish == 2 and game.inventory.food == 2, "Cooking preserves chosen fish properties and updates inventory")
	var benefit := Food.bonuses(original)
	game.health = 10
	game.hunger = 0
	check(game.eat() and game.health == 10 + benefit.health and game.hunger == benefit.hunger, "Eating restores the chosen fish nutrition exactly")
	check(game.food_items.size() == 1 and game.selected_food == 0, "Eating consumes one meal and keeps selection valid")
	game.food_items.append(Food.fish_item("mackerel", 1100))
	game.sync_provisions()
	game.select_provision(true)
	check(game.selected_food == 1, "Player can select another prepared meal")
	var saved_fish: Array = game.fish_items.duplicate(true)
	var saved_meals: Array = game.food_items.duplicate(true)
	var saved_casts: int = game.fishing.casts
	check(game.save_game(), "Detailed catch and meal inventory can be saved")
	game.fish_items.clear()
	game.food_items.clear()
	game.sync_provisions()
	check(game.load_game() and game.fish_items == saved_fish and game.food_items == saved_meals and game.selected_food == 1 and game.fishing.casts == saved_casts, "Load preserves every fish, meal, weight, rarity, selection and cast history")
	game.health = 99
	game.hunger = 99
	check(game.eat() and game.health == 100 and game.hunger == 100, "Nutrition respects the 100 point health and hunger limits")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	legacy.version = 1
	legacy.erase("fish_items")
	legacy.erase("food_items")
	legacy.erase("selected_fish")
	legacy.erase("selected_food")
	legacy.inventory.fish = 2
	legacy.inventory.food = 3
	var file := FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(game.load_game() and game.inventory.fish == 2 and game.inventory.food == 3 and game.fish_items[0].rarity == "common" and game.fish_items[0].weight == 300, "Old saves migrate quantities without losing food or fish")
	check(game.save_game() and int(JSON.parse_string(FileAccess.get_file_as_string(game.save_path)).version) == 2, "Migrated saves are written in the new format")
	game.food_items.clear()
	game.sync_provisions()
	check(not game.eat() and game.inventory.fish == 2, "Raw fish cannot be eaten as a cooked meal")
	print("RESULT: ", checks - failures, "/", checks, " provisions checks passed")
	game.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
