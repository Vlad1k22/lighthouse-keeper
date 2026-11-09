extends SceneTree

const ROOMS = preload("res://scripts/building_interiors.gd")
const DIRECTIONS := [
	[KEY_S], [KEY_S, KEY_D], [KEY_D], [KEY_D, KEY_W],
	[KEY_W], [KEY_W, KEY_A], [KEY_A], [KEY_A, KEY_S],
]
var game: Node3D
var player: CharacterBody3D
var interiors: Node3D
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
	await frames(23)

func move_with(keys: Array) -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		if Input.is_physical_key_pressed(code) != (code in keys):
			key(code, code in keys)

func walk(at: Vector3, tolerance := .15) -> bool:
	var reached := false
	for i in range(200):
		var remaining := at - player.position
		if Vector2(remaining.x, remaining.z).length() < tolerance:
			reached = true
			break
		var angle: float = atan2(remaining.x, remaining.z) - player.movement_yaw
		move_with(DIRECTIONS[posmod(roundi(angle/(TAU/8)), 8)])
		await physics_frame
	move_with([])
	await frames(11)
	if not reached:
		print("Walk blocked from ", player.position, " to ", at)
	return reached

func place(at: Vector3) -> void:
	player.position = at
	player.reset_motion()
	await frames(20)

func enter(id: String) -> bool:
	await tap(KEY_E)
	var current: Node3D = interiors.instances.get(id)
	var good: bool = interiors.active == id and player.is_on_floor() and current != null
	check(good, "E enters " + id + " with a solid floor")
	if not good:
		return false
	check(game.camera.environment == interiors.room_env and not current.get_node("Wall_South").visible and not current.get_node("Wall_East").visible, id + " uses a close third-person cutaway")
	check(game.map_player_position() == interiors.exit_at(id), id + " map marker stays on the real island or deck")
	return true

func at_action(id: String) -> bool:
	if not interiors.actions.has(id):
		return false
	var reached := await walk(interiors.actions[id])
	return reached and is_instance_valid(game.nearest_station) and game.nearest_station.station_id == id

func test_cabin() -> void:
	await place(Vector3(5,1.05,4.28))
	check(await walk(interiors.exit_at("cabin")), "Keeper walks up the original porch to the cabin door")
	if not await enter("cabin"):
		return
	check(await at_action("radio"), "The home radio can be reached indoors")
	await tap(KEY_E)
	check(game.journal_open and "radio" in game.journal_entries, "The indoor radio opens the original journal entry")
	await tap(KEY_J)
	game.fish_items.append(game.PROVISIONS.fish_item("perch", 400))
	game.sync_provisions()
	check(await at_action("cook"), "The stove can be reached indoors")
	await tap(KEY_E)
	check(game.fish_items.is_empty() and game.food_items.size()==2, "The indoor stove cooks the existing provision item")
	check(await at_action("shelter"), "The bunk uses the original rest action")
	var saved := player.position
	check(game.save_game(true), "A cabin position can be saved")
	game.start_shift()
	check(game.load_game() and interiors.active=="cabin" and player.position==saved, "Loading restores the cabin and its camera")
	await frames(12)
	check(await walk(interiors.spawn_at("cabin")), "The cabin exit is reachable from the bunk")
	await tap(KEY_E)
	check(interiors.active.is_empty() and game.world.visible and player.is_on_floor(), "The cabin exit returns to the porch")

func test_radio() -> void:
	await place(Vector3(-10.50,1.10,-35.73))
	check(await walk(interiors.exit_at("radio")), "Radio entrance is reachable beside the outdoor terminal")
	if not await enter("radio"):
		return
	var model: Node3D = interiors.instances["radio"]
	check(model.get_node("SignalOff").visible and not model.get_node("SignalOn").visible, "Unrepaired interior transmitter shows the fault indicator")
	game.day = 4
	game.expedition.state.merge({"tools":true,"battery":true,"scrap":2},true)
	check(await at_action("transmitter"), "Interior transmitter can be reached from the door")
	await tap(KEY_E)
	check(game.expedition.state.signal and game.expedition.state.scrap==0 and model.get_node("SignalOn").visible and not model.get_node("SignalOff").visible, "Repair consumes parts and updates both transmitter views")
	check(await walk(interiors.spawn_at("radio")), "Path back to the radio door is clear")
	await tap(KEY_E)
	check(interiors.active.is_empty() and player.is_on_floor() and game.camera.environment==null, "Radio exit returns to dry ground and restores the outdoor camera")

func test_warehouse() -> void:
	game.expedition.state.tools = false
	await place(Vector3(7,1.05,-26.4))
	check(await walk(Vector3(7,1,-30.85)), "Keeper enters the warehouse through its real open doorway")
	check(interiors.warehouse_open and not interiors.coast.get_node("CorrugatedRoof").visible and interiors.coast.get_node("WarehouseBack").visible, "Warehouse camera cuts the roof and foreground walls")
	check(interiors.shed_cutaway.size()>5 and interiors.shed_cutaway.all(func(node): return not node.visible), "Foreground pines clear the camera's view inside the warehouse")
	var before: int = game.expedition.state.scrap
	await tap(KEY_E)
	check(game.expedition.state.scrap==before+2, "The warehouse salvage station still gives two parts")
	check(await walk(Vector3(9,1,-32.0)) and is_instance_valid(game.nearest_station) and game.nearest_station.station_id=="tools", "The new warehouse props leave access to the tool bench")
	await tap(KEY_E)
	check(game.expedition.state.tools and not interiors.warehouse.get_node("ToolsPresent").visible, "Taking the tools removes the Blender toolbox")
	game.health = 65
	check(await walk(Vector3(9.83,1,-29.38)) and is_instance_valid(game.nearest_station) and game.nearest_station.station_id=="medical", "The medical locker can be reached from the bench")
	await tap(KEY_E)
	check(game.health==90, "The warehouse medicine heals the keeper")
	check(await walk(Vector3(7,1,-29.4)) and await walk(Vector3(7,1,-26.65)), "Keeper walks back out through the warehouse door")
	check(not interiors.warehouse_open and interiors.coast.get_node("CorrugatedRoof").visible, "Warehouse roof returns on exit")

func test_ship() -> void:
	await place(Vector3(-28.50,1.18,-21.0))
	check(await walk(Vector3(-33,1,-21)), "Keeper boards the actual deck by walking across the gangplank")
	check(player.is_on_floor() and absf(player.position.y-1.0)<.15, "The Blender ship still has physical deck support")
	var door: Vector3 = interiors.exit_at("ship")
	check(await walk(Vector3(door.x,1,-23.8)) and await walk(door), "Port-side deck route leads to the cabin door")
	if not await enter("ship"):
		return
	var origin: Vector3 = ROOMS.ROOMS.ship.origin
	check(await walk(origin+Vector3(.64,0,1.16)) and interiors.title(player.position).contains("КАЮТА"), "Keeper can walk across the furnished sleeping quarters")
	check(await walk(origin+Vector3(.05,0,.74)) and await at_action("ship_helm"), "The bulkhead opening connects the quarters to the helm")
	await tap(KEY_E)
	check(not game.expedition.sailing, "The indoor helm respects the ordinary departure requirements")
	check(await walk(origin+Vector3(.06,0,.73)) and await walk(interiors.spawn_at("ship")), "Keeper can return from the helm to the cabin door")
	await tap(KEY_E)
	check(interiors.active.is_empty() and player.is_on_floor() and player.position.distance_to(door)<.12, "The cabin exit puts the keeper back on deck")
	if not await enter("ship"):
		return
	check(await walk(origin+Vector3(.02,0,.75)) and await at_action("ship_helm"), "The helm remains accessible after re-entering")
	game.day = 7
	game.hour = 12
	game.expedition.state.merge({"hull":true,"engine":true,"ship_fuel":true,"stores":true,"signal":true},true)
	var z_before: float = interiors.vessel.position.z
	await tap(KEY_E)
	check(game.expedition.sailing and interiors.active.is_empty() and not player.enabled and game.world.visible, "Launching at the interior helm hands off to the moving deck")
	check(interiors.vessel.position.z<z_before-.3 and absf(player.position.z-interiors.vessel.position.z+4.55)<.14, "Player and ship travel together during departure")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.save_path = "user://automated_building_interiors.json"
	player = game.player
	interiors = game.building_interiors
	await test_cabin()
	game.campaign.enabled = false
	await test_radio()
	await test_warehouse()
	await test_ship()
	if FileAccess.file_exists(game.save_path):
		DirAccess.remove_absolute(game.save_path)
	print("BUILDING INTERIORS: %d/%d" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
