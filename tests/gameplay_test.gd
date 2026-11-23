extends SceneTree
## Новые занятия смотрителя: мини-игры, каменоломня, укрепления, огород и вороны, голод,
## письма в ящиках, фотоаппарат с фото-моментами и альбомом, авторассвет и быстрый подъём на маяк.
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func station(id: String) -> Area3D:
	for item in game.stations:
		if item.station_id == id:
			return item
	return null

func stand_at(id: String) -> Area3D:
	var item := station(id)
	game.player.position = item.position + Vector3(0, .3, .6)
	game.player.velocity = Vector3.ZERO
	game.interaction_cooldown = 0
	game.update_nearest()
	return item

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.save_path = "user://automated_gameplay.json"
	game.start_shift()
	game.hours_per_second = 0
	game.set_process(false)
	var mini: Control = game.minigames
	mini.enabled = true

	# --- Ремонт генератора через мини-игру ---
	game.inventory.fuel = 1
	var generator := stand_at("beacon")
	check(mini.offer(generator) and mini.visible and mini.kind == "beacon", "E at a fuelled generator opens the repair mini-game")
	mini.needle = 0.0
	mini.sector = 3.0
	mini.act()
	check(mini.misses == 1 and mini.hits == 0, "Pressing outside the green sector is a miss")
	for i in 3:
		mini.needle = mini.sector
		mini.act()
	check(mini.hits == 3 and mini.success, "Three accurate hits finish the repair")
	mini._process(2.0)
	check(not mini.visible and game.lighthouse_on and game.inventory.fuel == 0, "Finished repair starts the real generator")

	# --- Жарка рыбы ---
	game.fish_items.append(game.PROVISIONS.fish_item("perch", 400))
	game.sync_provisions()
	var stove := stand_at("cook")
	game.building_interiors.set_room("")
	check(mini.offer(stove) and mini.mode == mini.Mode.COOK, "E at the stove with fish opens the frying mini-game")
	for i in 2:
		mini.doneness = .72
		mini.act()
	mini._process(2.0)
	var meal: Dictionary = game.food_items.back()
	check(String(meal.get("recipe", "")) == "fried" and bool(meal.get("quality", false)), "Two golden flips give a quality fried fish")
	check(game.PROVISIONS.bonuses(meal).hunger > game.PROVISIONS.bonuses(game.PROVISIONS.fish_item("perch", 400)).hunger, "Fried fish is more filling than raw catch")

	# --- Костёр ---
	game.day = 6
	game.campaign.state.day = 6
	game.campaign.ensure_day()
	game.expedition.state.last_dawn = 6
	game.inventory.wood = 2
	var fire := stand_at("fire")
	check(mini.offer(fire) and mini.mode == mini.Mode.FIRE, "E at the harbour fire opens the fire-lighting mini-game")
	for i in 3:
		mini.striker = .5
		mini.act()
	check(mini.stage == 1, "Three good sparks light the tinder")
	mini.flame = .6
	mini.blowing = false
	for i in 30:
		mini.flame = .6
		mini._process(.1)
	mini._process(2.0)
	check(int(game.expedition.state.fire_day) == 6 and game.inventory.wood == 1, "Steady blowing lights the real harbour fire")

	# --- Каменоломня ---
	game.expedition.state.tools = true
	var stone_before := int(game.inventory.stone)
	check(game.attempt_interaction(stand_at("quarry")) and int(game.inventory.stone) == stone_before + 2, "The quarry yields stone with tools")
	game.minigame_result = "done"
	game.attempt_interaction(stand_at("quarry"))
	game.minigame_result = ""
	check(int(game.inventory.stone) == stone_before + 5, "A clean quarry mini-game gives an extra stone")
	game.homestead.quarry_used = game.homestead.QUARRY_DAILY
	check(not game.attempt_interaction(stand_at("quarry")), "The quarry has a daily limit")

	# --- Укрепления хижины ---
	game.barricade_built = true
	game.build_barricade()
	var base_hp: float = game.night_raids.max_hp()
	game.inventory.wood = 3
	check(game.attempt_interaction(stand_at("fort_n")) and game.homestead.levels.fort_n == 1, "Wood builds a fortification around the cabin")
	check(game.night_raids.max_hp() > base_hp and game.homestead.slot_nodes.has("fort_n"), "Each fortification adds barricade strength and a visible wall")
	game.inventory.stone = 8
	check(game.attempt_interaction(stand_at("fort_n")) and game.homestead.levels.fort_n == 2 and game.homestead.armor() > 0, "Stone upgrades the wall and adds armour")
	check(game.attempt_interaction(stand_at("workbench")) and game.homestead.levels.fort_front == 2, "The workbench clads the porch barricade in stone")

	# --- Огород и вороны ---
	var bed := stand_at("bed_0")
	check(game.attempt_interaction(bed) and game.homestead.beds[0].stage == 1, "A bed can be planted")
	check(not game.attempt_interaction(bed), "An empty watering can cannot water")
	check(game.attempt_interaction(stand_at("rain_barrel")) and game.homestead.can_water == game.homestead.CAN_SIZE, "The rain barrel fills the watering can")
	for stage in 3:
		game.interaction_cooldown = 0
		game.attempt_interaction(stand_at("bed_0"))
		game.homestead._grow(game.homestead.GROW_SECONDS + .1)
	check(game.homestead.beds[0].stage == 4, "Watered crops grow through three stages to harvest")
	var food_count: int = game.food_items.size()
	check(game.attempt_interaction(stand_at("bed_0")) and game.food_items.size() == food_count + 1 and String(game.food_items.back().kind) == "veg", "Harvest becomes edible food")
	game.homestead.beds[1] = {"stage":3,"water":true,"grow":0.0,"crop":1,"bird":false}
	game.player.position = Vector3(30, 1.2, 0)
	game.homestead._spawn_bird(1)
	for i in 160:
		game.homestead._birds(.1)
	check(game.homestead.beds[1].stage == 2, "An unchased crow pecks the crop back a stage")
	game.homestead.beds[2] = {"stage":3,"water":true,"grow":0.0,"crop":2,"bird":false}
	game.homestead._spawn_bird(2)
	for i in 40:
		game.homestead._birds(.1)
	game.player.position = game.homestead.BEDS[2] + Vector3(.5, .3, 0)
	game.homestead._birds(.1)
	check(game.homestead.beds[2].stage == 3 and game.homestead.scared == 1, "Running at the crow scares it away")

	# --- Голод ---
	game.hunger = 30
	game.apply_hunger(.1)
	check(game.lantern_beam.regen_scale < 1.0 and game.hud.overlay.alert_title == "ВЫ ГОЛОДНЫ", "Hunger slows recovery and warns the player")
	game.hunger = 10
	game.apply_hunger(.1)
	check(game.player.speed_scale < 1.0, "Starving slows the keeper down")
	game.hunger = 80
	game.apply_hunger(.1)

	# --- Письма в ящиках ---
	var events: Node3D = game.island_events
	game.player.position = Vector3(3, 1.2, 4)
	events.start("wreck")
	game.player.position = events.point + Vector3(.4, .3, 0)
	events.interact()
	check("letter:0" in game.journal_entries, "The first wreck crate always holds a letter")
	game.open_journal_entry("letter:0")
	check(game.hud.reader_title.text.begins_with("Письмо"), "Letters are readable in the journal")
	game.close_journal()

	# --- Фотоаппарат, фото-момент и альбом ---
	var photo: Control = game.photo
	check(game.attempt_interaction(stand_at("camera")) and photo.has_camera, "The old camera is picked up in the warehouse")
	game.day = 2
	game.campaign.state.day = 2
	game.campaign.ensure_day()
	game.campaign.state.night = false
	game.hour = 10
	photo.moments_done.clear()
	for i in 20:
		photo.advance(1.0)
	check(photo.moment.get("id", "") == "rainbow" and is_instance_valid(photo.moment_node), "A planned photo moment appears on its day")
	check(not game.hud.overlay.objective().is_empty() and not photo.banner().is_empty(), "The photo moment shows a banner")
	var image := Image.create(64, 40, false, Image.FORMAT_RGB8)
	image.fill(Color(.4, .6, .8))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://photos/test"))
	image.save_png("user://photos/test/photo_01.png")
	photo.photos = [{"path":"user://photos/test/photo_01.png","caption":"День 02 · тест","day":2,"selfie":false,"moment":"rainbow"}]
	var reel_finished := [false]
	check(game.album.play_reel(photo.photos, func(): reel_finished[0] = true) and game.album.visible, "The ending reel plays the shift's photos")
	for i in 30:
		game.album._process(.5)
	check(reel_finished[0] and not game.album.visible, "The reel finishes and hands over to the menu")
	check(game.save_game(true), "Save with homestead, camera and photos")
	photo.has_camera = false
	game.homestead.levels.fort_n = 0
	check(game.load_game() and photo.has_camera and photo.photos.size() == 1 and game.homestead.levels.fort_n == 2, "Camera, album and fortifications survive a reload")

	# --- Ночь с фиксированным временем и авторассветом ---
	game.day = 3
	game.campaign.state.day = 3
	game.campaign.ensure_day()
	for i in game.campaign.entry().goals.size():
		game.campaign.state.marks[str(i)] = true
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	game.barricade_built = true
	game.build_barricade()
	game.player.lantern_on = true
	game.hunger = 80
	check(game.campaign.begin_night(), "A prepared day starts its night")
	var seconds: float = game.campaign.entry().night.seconds
	check(seconds >= 45, "Nights last a fixed defence time of at least 45 seconds")
	game.campaign.advance(seconds * .5)
	check(game.day == 3 and game.campaign.state.night, "Dawn cannot be called early")
	game.player.position = station("shelter").position + Vector3(0, .3, .5)
	game.campaign.advance(5)
	game.campaign.state.event_done = true
	game.campaign.advance(seconds)
	check(game.day == 4 and not game.campaign.state.night, "Dawn arrives by itself when the defence time ends")

	# --- Быстрый подъём в маяке ---
	game.set_lighthouse_interior(true)
	game.player.position = game.LIGHTHOUSE_INTERIOR.ORIGIN + game.LIGHTHOUSE_INTERIOR.INSIDE_DOOR + Vector3.UP * .05
	game.lighthouse_quick_climb()
	await create_timer(.7).timeout
	check(game.player.position.y > game.LIGHTHOUSE_INTERIOR.ORIGIN.y + game.LIGHTHOUSE_INTERIOR.TOP - .5, "Space in the lighthouse climbs straight to the lens")
	check(game.player.indoor_running and game.player.indoor_speed > 3.0, "The lighthouse stairs allow running")
	game.set_lighthouse_interior(false)

	# --- Рябь причала ---
	var plank: Node3D = game.world.get_node("NorthernCoast/PierPlank")
	var base: Node3D = game.world.get_node("NorthernCoast/HarborFoundation")
	var plank_top: float = (plank.global_transform * plank.get_aabb()).end.y
	var base_top: float = (base.global_transform * base.get_aabb()).end.y
	check(absf(plank_top - base_top) > .005, "Pier planks no longer share a plane with the harbour foundation")

	# --- Радиостанция и рубка: внутрь обязательно ---
	if game.journal_open: game.close_journal()
	game.hud.fading = false
	var outdoor_tx := stand_at("transmitter")
	game.update_nearest()
	check(game.interior_redirect(outdoor_tx), "E at the outdoor transmitter leads into the radio booth")
	await create_timer(.7).timeout
	check(game.building_interiors.active == "radio", "The keeper is now inside the radio booth")
	var radio_room: Node3D = game.building_interiors.instances["radio"]
	check(radio_room.has_node("ForecastBoard") and "СВОДКА" in game.extras.forecast_board.text, "The radio booth has a forecast board")
	game.player.position = game.building_interiors.ROOMS.radio.origin + Vector3(-1.75, .04, .62)
	var sanity_before: float = game.sanity
	game.sanity = 50
	check(game.extras.nearby() == "forecast" and game.extras.interact(), "The forecast can be read on the board")
	check(game.sanity >= 58 and game.extras.forecast_bonus() > 1.0 and "forecast" in game.journal_entries, "Reading the forecast calms the keeper and boosts the lantern tonight")
	if game.journal_open: game.close_journal()
	game.sanity = sanity_before
	game.exit_building()
	game.enter_building("ship")
	game.player.position = game.building_interiors.ROOMS.ship.origin + Vector3(-1.6, .04, -1.05)
	check(game.building_interiors.instances["ship"].has_node("CaptainPortrait") and game.extras.nearby() == "captain", "The captain's portrait hangs in the wheelhouse")
	game.sanity = 40
	game.extras.interact()
	check(game.sanity >= 50 and game.radio.current == "captain_ready", "Saluting the captain plays his line and restores sanity")
	check(game.viewer.visible and game.paused and game.viewer.texture != null, "The portrait opens as a sharp close-up")
	game.viewer.close()
	check(not game.viewer.visible and not game.paused and game.player.enabled, "Closing the close-up returns control")
	game.extras.interact()
	game.viewer.close()
	check(game.sanity < 61 and game.radio.current == "captain_louder", "The captain wants it louder, but the bonus is once a day")
	if game.journal_open: game.close_journal()
	game.exit_building()
	game.enter_building("cabin")
	game.player.position = game.building_interiors.ROOMS.cabin.origin + Vector3(-2.0, .04, .55)
	check(game.building_interiors.instances["cabin"].has_node("Poster") and game.extras.nearby() == "poster", "The island poster hangs in the cabin")
	game.extras.interact()
	check("poster" in game.journal_entries and game.viewer.visible and game.viewer.title.contains("ПЛАКАТ"), "The poster opens as a close-up and becomes a journal find")
	game.viewer.close()
	if game.journal_open: game.close_journal()
	game.exit_building()
	game.player.position = game.extras.SIGN_AT + Vector3(.6, .1, .7)
	check(game.world.has_node("HayDaySign") and game.extras.nearby() == "hayday", "The Hay Day sign stands by the garden")
	game.extras.interact()
	check("hayday" in game.journal_entries and game.viewer.visible, "The farm sign opens as a close-up and is a journal find")
	game.viewer.close()
	if game.journal_open: game.close_journal()
	var saved: Dictionary = game.extras.save_data()
	game.extras.restore({})
	game.extras.restore(saved)
	check(game.extras.captain_day == game.day and game.extras.forecast_day == game.day, "Daily interior bonuses survive save and load")

	print("GAMEPLAY_CHECKS ", checks, " failures ", failures)
	quit(1 if failures > 0 else 0)
