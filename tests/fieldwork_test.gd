extends SceneTree

var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: "+description)

func tap(code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
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
	game.interaction_cooldown = 0
	for i in 8:await physics_frame
	game.update_nearest()

func finish_gauge(work: Control, good: bool) -> void:
	if good:
		for i in 180:
			if not work.visible:break
			var midpoint: float = (work.bounds.x+work.bounds.y)*.5
			work.tick(.04,work.gauge<midpoint)
	else:
		work.tick(8,false)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.save_path = "user://automated_fieldwork.json"
	var work: Control = game.hud.fieldwork
	var radio: Control = game.hud.tuner
	await place(Vector3(-4.5,1.12,6.8))
	await tap(KEY_G)
	check(work.visible and game.paused,"G opens dry-log selection at the real wood pile")
	await tap(KEY_ESCAPE)
	check(game.inventory.wood==0 and game.survival.wood_bonus_day==0,"Cancelling wood selection leaves the pile and daily bonus intact")
	await tap(KEY_G)
	work.choose(work.dry_slot)
	check(game.inventory.wood==2 and game.survival.wood_bonus_day==1,"Dry log grants the normal wood and one bonus")
	await tap(KEY_G)
	check(not work.visible and game.inventory.wood==2,"The dry-log bonus cannot be repeated on the same day")
	await place(Vector3(-4.5,1.12,6.8))
	await tap(KEY_E)
	check(game.inventory.wood==3,"Ordinary wood collection still works")
	game.day = 2
	await place(Vector3(-20.5,1.12,-23))
	await tap(KEY_G)
	check(work.visible and work.mode==work.Mode.FUEL,"G opens the fuel pump gauge at the harbor")
	var early_width: float = work.bounds.y-work.bounds.x
	var pressure_key := InputEventKey.new()
	pressure_key.physical_keycode = KEY_SPACE
	pressure_key.keycode = KEY_SPACE
	pressure_key.pressed = true
	Input.parse_input_event(pressure_key)
	await process_frame
	check(work.holding,"Pressing Space controls the actual pressure gauge")
	pressure_key = pressure_key.duplicate()
	pressure_key.pressed = false
	Input.parse_input_event(pressure_key)
	await process_frame
	check(not work.holding,"Releasing Space lets pressure fall")
	finish_gauge(work,true)
	check(game.inventory.fuel==3 and game.expedition.used("depot"),"Stable pressure grants three cans and uses the daily stock")
	game.day = 10
	await tap(KEY_G)
	check(work.visible and work.bounds.y-work.bounds.x<early_width,"Late pressure control has a narrower safe range")
	finish_gauge(work,false)
	check(game.inventory.fuel==5 and game.expedition.used("depot"),"Poor pressure still yields the two ordinary cans")

	game.day = 3
	await place(Vector3(1.5,1.12,-21.7))
	await tap(KEY_H)
	check(game.survival.water==0,"The broken pump cannot fill a flask")
	game.expedition.state.pump = true
	await tap(KEY_H)
	check(game.survival.water==3,"H fills three portions at the repaired pump")
	game.set_building_interior("cabin")
	await place(game.building_interiors.actions["cook"]+Vector3.UP*.03)
	game.player.stamina = 44
	game.sanity = 80
	await tap(KEY_H)
	check(game.survival.water==2 and game.player.stamina>=68 and game.sanity>=85,"Drinking elsewhere consumes one portion and restores stamina and sanity")
	game.fish_items.append(game.PROVISIONS.fish_item("mackerel",980))
	game.fish_items.append(game.PROVISIONS.fish_item("perch",450))
	game.sync_provisions()
	await tap(KEY_K)
	check(work.visible and not work.buttons[0].disabled and not work.buttons[1].disabled,"The real cabin stove offers both recipes")
	await tap(KEY_3)
	check(game.survival.stove_time>150 and game.inventory.wood==2 and work.buttons[2].disabled,"Heating burns one wood and prevents immediate repeated fuel use")
	await tap(KEY_1)
	await tap(KEY_ESCAPE)
	check(game.fish_items.size()==2 and game.survival.water==2,"Cancelling the cooking gauge does not consume ingredients")
	await tap(KEY_K)
	await tap(KEY_1)
	finish_gauge(work,true)
	check(game.survival.water==1 and game.fish_items.size()==1 and game.food_items.back().get("quality",false),"Steady heat makes quality soup from the selected fish")
	await tap(KEY_K)
	await tap(KEY_2)
	finish_gauge(work,false)
	check(game.inventory.wood==1 and game.fish_items.is_empty() and game.food_items.back().get("recipe","")=="smoked" and not game.food_items.back().get("quality",true),"Missing the cooking target still produces smoked fish")
	var soup: Dictionary = game.food_items[1]
	var basic: Dictionary = game.PROVISIONS.crafted(game.PROVISIONS.fish_item("mackerel",980),"soup",false)
	check(soup.weight==980 and soup.rarity=="rare" and game.PROVISIONS.bonuses(soup).hunger>game.PROVISIONS.bonuses(basic).hunger,"Recipe preserves weight and rarity and quality improves the dish")
	check(game.PROVISIONS.cargo_index([game.food_items.back(),soup])==0,"Ship loading prioritizes smoked fish")

	await place(game.building_interiors.actions["radio"]+Vector3.UP*.03)
	await tap(KEY_U)
	check(radio.visible and game.paused,"U opens the tuner at the home receiver")
	radio.dial.value = 978
	await tap(KEY_E)
	check(radio.LOG not in game.journal_entries,"The previous shift broadcast is gated by campaign day")
	game.day = 8
	await tap(KEY_E)
	await tap(KEY_E)
	radio.dial.value = 1023
	await tap(KEY_E)
	check(game.journal_entries.count(radio.LOG)==1 and radio.CREW in game.journal_entries,"Optional frequencies add two distinct entries without duplicates")
	await tap(KEY_J)
	check(game.journal_open and game.journal_entries[game.journal_page]==radio.CREW,"The tuner can open the decoded clue directly")
	await tap(KEY_J)
	game.survival.warmth = 33
	check(game.save_game(true) and game.load_game() and game.survival.water==1 and game.survival.stove_time>140 and absf(game.survival.warmth-33)<1 and game.food_items[1].quality and radio.CREW in game.journal_entries,"Save round-trip preserves water, warmth, stove, recipes and broadcasts")
	game.survival.warmth = 18
	game.selected_food = 1
	check(game.eat() and game.survival.warmth>=56 and game.survival.meal_warmth_time>80,"Quality soup gives warmth immediately and for the next outing")

	game.day = 11
	game.campaign.ensure_day()
	game.campaign.state.night = true
	await place(game.building_interiors.actions["radio"]+Vector3.UP*.03)
	await tap(KEY_E)
	check(radio.visible and radio.verifying,"E opens night verification at the actual cabin radio")
	await tap(KEY_1)
	check(radio.visible and not game.campaign.state.event_done,"A false call stays pending through the keyboard UI")
	await tap(KEY_J)
	check(game.journal_open and game.journal_entries[game.journal_page]==radio.CHECK_11,"J shows the exact verification note")
	await tap(KEY_J)
	await tap(KEY_E)
	await tap(KEY_2)
	check(not radio.visible and game.campaign.state.event_done,"A matching call resolves the night through the keyboard UI")

	game.set_building_interior("")
	await place(Vector3(3,1.12,4))
	game.day = 12
	game.campaign.ensure_day()
	game.hour = 22
	game.survival.warmth = 24
	game.survival.meal_warmth_time = 0
	game.coastal_life.rain_strength = 1
	game.survival.advance(10)
	check(game.survival.warmth<20 and game.player.stamina_recovery_scale<.8,"A late rainy outing causes cold and slower stamina recovery")
	game.set_building_interior("cabin")
	game.survival.advance(10)
	check(game.survival.warmth>40,"The lit stove warms the keeper in shelter")

	DirAccess.remove_absolute(game.save_path)
	print("FIELDWORK AND RADIO: %d/%d" % [checks-failures,checks])
	game.queue_free()
	await create_timer(.25).timeout
	quit(0 if failures==0 else 1)
