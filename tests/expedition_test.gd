extends SceneTree
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: "+description)

func station(id: String) -> Area3D:
	for item in game.stations:
		if item.station_id==id: return item
	return null

func interact(id: String) -> bool:
	var item := station(id)
	game.player.position = item.position+Vector3(0,0.3,0.5)
	game.player.velocity = Vector3.ZERO
	return game.attempt_interaction(item)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Isolate the retained free-roam economy; the full 30-day story has its own playthrough test.
	game.campaign.enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.save_path = "user://automated_expedition_test.json"
	var ex = game.expedition
	check(game.stations.size()==26,"Northern coast adds seventeen interactables")
	check(not interact("ship_helm") and not game.finished,"Unprepared vessel cannot depart")
	check(not interact("tools"),"Tools unlock on day two")
	check(not interact("ship_hull") and game.inventory.wood==0,"Early hull repair cannot charge resources")
	check(interact("fuel") and interact("beacon"),"First-day lighthouse works")
	for i in 3: interact("wood")
	check(interact("workbench"),"Original first-day shelter can be built")
	check(interact("cache") and game.food_items.size()==3,"Harbor cache adds two real food items")
	check(not interact("cache") and game.food_items.size()==3,"Unique cache cannot be farmed")
	check(interact("depot") and game.inventory.fuel==2,"Daily depot gives fuel for lighthouse and boat")
	check(not interact("depot") and game.inventory.fuel==2,"Daily fuel cannot be collected twice")
	check(interact("scrap") and int(ex.state.scrap)==2,"Warehouse awards two parts")
	check(not interact("scrap") and int(ex.state.scrap)==2,"Daily parts cannot be collected twice")
	game.health = 60
	check(interact("medical") and game.health==85,"Medical cabinet restores twenty-five health")
	check(not interact("medical") and game.health==85,"Medical cabinet has daily limit")
	check(interact("north_wood") and game.inventory.wood==2,"Northern wood gives two timber")
	check(interact("fire") and game.is_safe(Vector3(-16,1,-28)),"Fueled campfire creates a real safe zone")
	game.fish_items.append(game.PROVISIONS.fish_item("perch",450))
	game.sync_provisions()
	check(interact("trap") and game.fish_items.is_empty(),"Trap consumes a real fish as bait")
	check(not interact("trap"),"Trap cannot be harvested immediately")
	check(not interact("shelter"),"Sleep is unavailable during day")
	game.hour = 22
	check(interact("shelter") and game.day==2 and game.hour==7 and not game.finished,"Shelter advances to playable second day")
	check(not game.lighthouse_on and not game.is_safe(Vector3(-16,1,-28)),"Dawn extinguishes lighthouse and harbor fire")
	var day_before: int = game.day
	ex.dawn()
	check(game.day==day_before,"Dawn transition is idempotent")
	check(interact("tools") and ex.state.tools,"Day two unlocks repair tools")
	check(not interact("tools"),"Tools cannot be collected twice")
	check(interact("trap") and game.fish_items.size()==2,"Next-day trap yields two fish")
	check(interact("depot") and game.inventory.fuel==4,"Fuel stock renews next calendar day")
	check(interact("scrap") and int(ex.state.scrap)==4,"Parts stock renews next calendar day")
	check(interact("north_wood") and game.inventory.wood==3,"Wood renews next day")
	check(not interact("pump"),"Pump repair unlocks on day three")
	for number in range(2,7):
		if number>=3:
			interact("depot")
			interact("scrap")
			interact("north_wood")
		if number==3:
			check(interact("pump") and ex.state.pump and int(ex.state.scrap)==4,"Pump repair consumes two parts and one wood")
			game.hunger = 50
			check(interact("pump") and game.hunger==62,"Working pump restores daily water supply")
			check(not interact("pump") and game.hunger==62,"Water has a daily use limit")
		if number==4:
			check(not interact("transmitter"),"Transmitter rejects missing battery")
			check(interact("battery") and interact("transmitter") and ex.state.signal,"Wreck battery restores rescue transmitter")
			check(not interact("battery"),"Wreck battery is unique")
		if number==5:
			var before: int = game.inventory.wood
			check(interact("ship_hull") and ex.state.hull and game.inventory.wood==before-5,"Hull repair deducts five timber")
			check(not interact("ship_hull") and game.inventory.wood==before-5,"Repeated repair cannot consume more resources")
		if number==6:
			check(interact("ship_engine") and ex.state.engine,"Collected daily parts are enough for engine")
			check(interact("ship_fuel") and ex.state.ship_fuel,"Boat tank consumes three saved fuel")
		interact("beacon")
		game.hour = 22
		check(interact("shelter") and game.day==number+1,"Sleep opens day "+str(number+1))
	check(interact("ship_stores") and ex.state.stores and game.food_items.is_empty(),"Three food items become ship provisions")
	check(ex.ready_to_sail(),"Seven-day survival resource economy can prepare complete boat")
	game.player.position = Vector3(-33,1.3,-27.3)
	check(game.save_game(),"Free-roam state saves in the current version")
	var old_state: Dictionary = ex.state.duplicate(true)
	ex.state.scrap = 99
	ex.state.hull = false
	check(game.load_game() and ex.state==old_state and game.day==7,"Save reload preserves ship, repairs, resources and daily limits")
	game.hour = 22
	check(not interact("ship_helm") and not ex.sailing,"Sailing is blocked at night")
	game.hour = 10
	game.hours_per_second = 1
	ex.open_board()
	var previous_hour: float = game.hour
	await process_frame
	check(game.paused and not game.player.enabled and game.hour==previous_hour,"Map pauses time and movement")
	ex.close_board()
	game.hours_per_second = 0
	check(not game.paused and game.player.enabled,"Closing map restores controls")
	check(interact("ship_helm") and ex.sailing and not game.player.enabled,"Prepared helm starts sailing sequence")
	check(not game.save_game(),"Cannot save during departure")
	var old_z: float = game.player.position.z
	ex.advance(3)
	check(game.player.position.z<old_z-8 and not game.finished,"Ship and passenger actually move towards sea")
	ex.advance(5)
	check(game.finished and game.hud.menu.visible,"Departure completes campaign ending")
	game.playing = false
	game.start_shift()
	check(game.day==1 and not ex.state.engine and int(ex.state.scrap)==0,"New game clears all expedition state")
	check(game.world.get_node("NorthernCoast/CoastalVessel").position==Vector3(-33,0,-24),"New game restores ship to berth")
	ex.state.fire_day = 1
	game.hour = 23.95
	game.hours_per_second = 1
	game._process(0.1)
	game.hours_per_second = 0
	check(game.day==2 and int(ex.state.last_dawn)==1,"Natural midnight changes calendar without processing dawn twice")
	check(game.is_safe(Vector3(-16,1,-28)),"Harbor fire remains protective after midnight")
	game.hour = 6.1
	game._process(0.01)
	check(game.day==2 and int(ex.state.last_dawn)==2 and int(ex.state.fire_day)==0,"Natural dawn resets daily state once")
	game.day = 8
	ex.dawn()
	check(not ex.day_complete(),"Day eight begins with a new daily timber task")
	interact("north_wood")
	check(ex.day_complete(),"Day eight timber task can actually be completed")
	game.day = 10
	ex.state.pump = true
	ex.dawn()
	check(not ex.day_complete() and interact("pump") and ex.day_complete(),"Later rotating water task is actionable")
	game.day = 30
	ex.state.last_dawn = 30
	game.lighthouse_on = true
	game.barricade_built = true
	game.hour = 22
	interact("shelter")
	check(game.day==31 and game.finished,"Thirty-day deadline has a failure ending")
	game.playing = false
	game.start_shift()
	game.save_game()
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	legacy.version = 2
	legacy.erase("expedition")
	var file := FileAccess.open(game.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(game.load_game() and game.day==1 and not ex.state.tools and game.food_items.size()==1,"Version two saves without campaign data remain compatible")
	print("RESULT: ",checks-failures,"/",checks," expedition checks passed")
	game.queue_free()
	await create_timer(0.3).timeout
	quit(0 if failures==0 else 1)
