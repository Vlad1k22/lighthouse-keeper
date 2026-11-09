extends SceneTree

var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)

func tap(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame

func place(at: Vector3) -> void:
	game.player.position = at
	game.player.reset_motion()
	game.interaction_cooldown = 0.0
	for i in 12:await physics_frame
	game.update_nearest()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.save_path = "user://automated_backpack_inventory.json"
	var backpack = game.hud.backpack
	var salvage = game.hud.salvage
	game.fish_items.append(game.PROVISIONS.fish_item("perch",360))
	game.fish_items.append(game.PROVISIONS.fish_item("mackerel",1250))
	game.food_items.append(game.PROVISIONS.fish_item("perch",420))
	game.sync_provisions()
	await tap(KEY_B)
	var clock: float = game.campaign.state.day_clock
	check(backpack.visible and game.paused and not game.player.enabled,"B opens the backpack and freezes movement")
	await process_frame
	await process_frame
	check(is_equal_approx(clock,game.campaign.state.day_clock),"The backpack freezes campaign time")
	backpack.tab_buttons[1].pressed.emit()
	backpack.list.select(1)
	backpack.refresh_details()
	check(backpack.caption.text=="Скумбрия" and backpack.details.text.contains("1250") and backpack.second.disabled,"Catch details show weight and lock cooking away from a stove")
	backpack.first.pressed.emit()
	check(game.selected_fish==1 and backpack.list.get_item_text(1).begins_with("◆"),"Pinning a fish uses the existing selected-catch field")
	backpack.tab_buttons[2].pressed.emit()
	backpack.list.select(1)
	backpack.refresh_details()
	backpack.second.pressed.emit()
	check(game.selected_food==1 and backpack.list.get_item_text(1).begins_with("◆"),"Pinning a dish selects the real quick slot R")
	game.health = 30
	game.hunger = 40
	backpack.list.select(0)
	backpack.refresh_details()
	backpack.first.pressed.emit()
	check(game.food_items.size()==1 and game.hunger==75 and game.health==35,"The backpack consumes exactly the selected meal")
	backpack.tab_buttons[3].pressed.emit()
	var lamp: bool = game.player.lantern_on
	backpack.first.pressed.emit()
	check(game.player.lantern_on!=lamp,"Equipment can operate the actual lantern")
	await tap(KEY_ESCAPE)
	check(not backpack.visible and game.player.enabled and not game.paused,"Esc closes the backpack without opening the pause menu")
	game.set_building_interior("cabin")
	await place(game.building_interiors.actions["cook"]+Vector3.UP*.025)
	await tap(KEY_B)
	backpack.tab_buttons[1].pressed.emit()
	backpack.list.select(1)
	backpack.refresh_details()
	check(not backpack.second.disabled,"The backpack enables cooking next to the real stove")
	backpack.second.pressed.emit()
	check(not backpack.visible and game.fish_items.size()==1 and game.food_items.back().weight==1250,"Cooking uses the chosen fish and its original weight")
	game.set_building_interior("")
	game.day = 2
	await place(Vector3(7,1.06,-30.85))
	await tap(KEY_G)
	check(salvage.visible and game.paused and game.expedition.state.scrap==0,"G opens salvage without granting parts upfront")
	await tap(KEY_ESCAPE)
	check(not salvage.visible and not game.expedition.used("scrap") and game.expedition.state.scrap==0,"Cancelling preserves the daily visit and resources")
	await tap(KEY_G)
	for i in salvage.CENTERS.size():
		salvage.progress = salvage.CENTERS[i]
		await tap(KEY_SPACE)
	check(game.expedition.used("scrap") and game.expedition.state.scrap==4 and not game.paused,"Three precise actions grant two base parts and two bonus parts")
	await tap(KEY_G)
	check(not salvage.visible and game.expedition.state.scrap==4,"A second attempt cannot grant parts on the same day")
	game.day = 10
	await tap(KEY_G)
	check(salvage.visible and salvage.width<salvage.profile(2).x and salvage.speed>salvage.profile(2).y,"Late shifts have a smaller window and faster marker")
	for i in salvage.CENTERS.size():
		salvage.progress = 0
		await tap(KEY_SPACE)
	check(game.expedition.state.scrap==6 and game.expedition.used("scrap"),"Missed inputs still give the ordinary two parts")
	check(game.save_game(true) and game.load_game() and game.expedition.state.scrap==6 and game.food_items.back().weight==1250 and game.expedition.used("scrap"),"A reload preserves new rewards, the original item data and the daily allowance")
	game.fish_items.append(game.PROVISIONS.fish_item("sturgeon",1550))
	game.sync_provisions()
	await place(Vector3(-25,1.12,-19.02))
	await tap(KEY_B)
	backpack.tab_buttons[1].pressed.emit()
	backpack.list.select(1)
	backpack.refresh_details()
	check(not backpack.third.disabled,"The backpack enables bait beside an empty trap")
	backpack.third.pressed.emit()
	check(not backpack.visible and game.expedition.state.trap_day==10 and game.fish_items.size()==1 and game.fish_items[0].species=="perch","Bait uses exactly the selected catch")
	DirAccess.remove_absolute(game.save_path)
	print("BACKPACK AND SALVAGE: %d/%d" % [checks-failures,checks])
	game.queue_free()
	await create_timer(.25).timeout
	quit(0 if failures==0 else 1)
