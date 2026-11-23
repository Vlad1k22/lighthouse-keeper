extends SceneTree
## Динамика: луч фонаря, луч маяка, ночные волны, дневные происшествия и подсказки целей.
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

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.save_path = "user://automated_dynamics.json"
	game.start_shift()
	await process_frame

	# --- Точки появления и события стоят на настоящей земле ---
	var edge_ok := 0
	for point in game.night_raids.EDGE_POINTS:
		if game.night_raids.ground_at(point) != null:
			edge_ok += 1
	check(edge_ok >= 6, "At least six raid entry points stand on solid ground (%d)" % edge_ok)
	var shore_ok := 0
	for point in game.island_events.SHORE:
		if game.night_raids.ground_at(point) != null:
			shore_ok += 1
	check(shore_ok >= 6, "At least six shore event spots stand on solid ground (%d)" % shore_ok)
	check(game.night_raids.ground_at(Vector3(60, 1, 60)) == null, "Open sea is rejected as a spawn point")

	# --- Маркер цели ведёт к первой задаче ---
	await process_frame
	var overlay: Control = game.hud.overlay
	check(overlay.has_target and overlay.target_name != "", "Objective marker knows where the current goal is")
	check(is_instance_valid(overlay.marker) and overlay.marker.visible, "Objective marker is visible in the world")
	check(overlay.card_time > 0 and overlay.card_title.begins_with("ДЕНЬ 01"), "A title card introduces the first day")

	# --- Радиоэфир с нейроозвучкой и строка цели ---
	var radio: Node = game.radio
	var voiced := 0
	for id in radio.LINES:
		var stream: AudioStream = radio.stream_for(id)
		if stream != null and stream.get_length() > 1.5:
			voiced += 1
	check(voiced == radio.LINES.size(), "Every radio line has a voiced clip (%d/%d)" % [voiced, radio.LINES.size()])
	check(radio.played.has("brief_1") and radio.speaking(), "The first morning briefing plays on the radio")
	check(radio.subtitle().text.contains("канистру"), "Radio subtitle shows what the dispatcher says")
	check(not game.hud.message_label.visible, "Radio subtitles replace the overlapping message line")
	check(String(overlay.objective().text).contains("канистру"), "Objective bar names the first concrete action")
	radio.say("event_wreck")
	radio.say("event_fog")
	radio.say("event_shoal")
	check(radio.queue.size() == 2, "Radio queue keeps at most two waiting lines")
	radio.reset()

	# --- Луч фонаря выжигает тень перед смотрителем ---
	game.set_process(false)
	game.player.position = Vector3(-3, 1.2, 3)
	game.player.lantern_on = true
	game.player.enabled = true
	var front: CharacterBody3D = game.spawn_shadow(Vector3(-3, 1.2, 7.5))
	var behind: CharacterBody3D = game.spawn_shadow(Vector3(-3, 1.2, -1.5))
	front.set_physics_process(false)
	behind.set_physics_process(false)
	var beam: Node3D = game.lantern_beam
	beam.forced = true
	beam.aim_override = Vector3(0, 0, 1)
	var dispelled_before: int = game.shadows_dispelled
	for i in 30:
		beam.tick(1.0 / 30.0, true)
	check(beam.focusing and front.darkness < front.max_darkness, "Focused beam burns the shadow it points at")
	check(behind.darkness == behind.max_darkness, "Shadow behind the keeper is untouched")
	check(beam.charge < 100 and game.player.focus_direction != Vector3.ZERO, "Focusing drains charge and turns the keeper")
	for i in 60:
		beam.tick(1.0 / 30.0, true)
	check(front.is_dissolving() and game.shadows_dispelled == dispelled_before + 1, "Burned shadow dissolves and is counted")
	for i in 400:
		beam.tick(1.0 / 30.0, true)
	check(beam.exhausted and not beam.focusing, "Overheated lantern stops the beam")
	beam.forced = false
	for i in 150:
		beam.tick(1.0 / 30.0, true)
	check(not beam.exhausted and beam.charge > beam.UNLOCK_AT, "Lantern cools down and recharges")
	beam.aim_override = Vector3.ZERO
	game.clear_enemies()

	# --- Луч маяка обжигает тени на своём пути ---
	game.hour = 22
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	var direction: Vector3 = beam.beacon_direction()
	var in_beam: Vector3 = game.beacon.global_position + direction * 12.0
	in_beam.y = 1.2
	check(beam.in_beacon_beam(in_beam), "A point twelve metres along the lighthouse beam is lit")
	check(not beam.in_beacon_beam(game.beacon.global_position - direction * 12.0), "The opposite side of the lighthouse is dark")
	var swept: CharacterBody3D = game.spawn_shadow(in_beam)
	swept.set_physics_process(false)
	beam.tick(.5, true)
	check(swept.darkness < swept.max_darkness, "Lighthouse beam burns shadows it sweeps over")
	game.clear_enemies()

	# --- Ночная осада: волна, генератор, баррикада ---
	game.campaign.state.day = 3
	game.day = 3
	game.campaign.ensure_day()
	game.campaign.state.night = true
	game.campaign.state.night_clock = 0.0
	game.barricade_built = true
	game.build_barricade()
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	game.player.position = Vector3(5, 1.2, 2)
	var raids: Node = game.night_raids
	raids.reset()
	raids.advance(6.0)
	check(raids.active and raids.wave == 1 and game.enemies.size() >= 1, "Night raid starts with a first wave")
	check(overlay.alert_time > 0 and overlay.alert_title.begins_with("ВОЛНА 1"), "Wave is announced on screen")
	var goals := {}
	for enemy in game.enemies:
		goals[enemy.goal] = true
	check(goals.has("generator") or goals.has("barricade"), "Raiders target the light, not only the keeper")
	game.clear_enemies()
	var saboteur: CharacterBody3D = game.spawn_shadow(raids.GENERATOR + Vector3(.6, .3, .6))
	saboteur.goal = "generator"
	saboteur.goal_point = raids.GENERATOR
	game.player.position = Vector3(18, 1.2, 6)
	await frames(200)
	check(not game.lighthouse_on and raids.sabotaged, "Raider at the generator cuts the lighthouse power")
	check(saboteur.goal == "", "After the blackout the raider turns on the keeper")
	game.clear_enemies()
	var generator: Area3D
	var workbench: Area3D
	for station in game.stations:
		if station.station_id == "beacon":
			generator = station
		elif station.station_id == "workbench":
			workbench = station
	game.player.position = generator.position + Vector3(0, .3, .8)
	game.interaction_cooldown = 0
	check(game.attempt_interaction(generator) and game.lighthouse_on and not raids.sabotaged, "E at the generator restores the sabotaged light")
	var breaker: CharacterBody3D = game.spawn_shadow(raids.BARRICADE_FRONT + Vector3(0, .3, .4))
	breaker.goal = "barricade"
	breaker.goal_point = raids.BARRICADE_FRONT
	game.player.position = Vector3(18, 1.2, 6)
	raids.barricade_hp = 6
	await frames(90)
	check(not game.barricade_built and raids.barricade_broken and not is_instance_valid(game.barricade), "Raiders can break the barricade")
	check(not game.is_safe(Vector3(5, 1, 3)) or game.lighthouse_on and Vector2(5 + 9, 3 + 7).length() < 8, "A broken barricade no longer shelters the cabin")
	game.clear_enemies()
	game.inventory.wood = 1
	game.player.position = workbench.position + Vector3(0, .3, .8)
	game.interaction_cooldown = 0
	check(game.attempt_interaction(workbench) and game.barricade_built and game.inventory.wood == 0, "One wood repairs the broken barricade")
	raids.dispelled = 5
	var scrap_before := int(game.expedition.state.scrap)
	raids.on_dawn()
	check(int(game.expedition.state.scrap) == scrap_before + 2 and game.night_report.contains("рассеяно теней: 5"), "Dawn rewards brave nights with parts")
	game.campaign.state.night = false
	game.clear_enemies()

	# --- Дневные происшествия ---
	var events: Node3D = game.island_events
	game.day = 4
	game.campaign.state.day = 4
	game.campaign.ensure_day()
	game.player.position = Vector3(3, 1.2, 4)
	check(events.start("wreck") and events.is_active() and is_instance_valid(events.prop), "Wreck event washes a crate ashore")
	check(not events.banner().is_empty() and is_instance_valid(events.marker), "Event shows a timer banner and a light marker")
	var wood_before: int = game.inventory.wood
	var fuel_before: int = game.inventory.fuel
	var scrap_mid := int(game.expedition.state.scrap)
	var food_before: int = game.food_items.size()
	game.player.position = events.point + Vector3(.5, .3, 0)
	check(events.prompt().contains("Вскрыть"), "Crate offers an E prompt nearby")
	check(events.interact() and not events.is_active(), "Opening the crate resolves the event")
	check(game.inventory.wood > wood_before or game.inventory.fuel > fuel_before or int(game.expedition.state.scrap) > scrap_mid or game.food_items.size() > food_before, "Crate grants real supplies")
	game.player.position = Vector3(3, 1.2, 4)
	check(events.start("bottle"), "Bottle event can start")
	game.player.position = events.point + Vector3(.4, .3, 0)
	check(events.interact() and "bottle:0" in game.journal_entries, "Bottle note is added to the journal")
	game.open_journal_entry("bottle:0")
	check(game.hud.reader_title.text.begins_with("Бутылка"), "Bottle note is readable in the journal")
	game.close_journal()
	game.campaign.state.beacon_charge = 2
	check(events.start("sparks"), "Generator sparks event can start")
	events.time_left = 0.01
	events.advance(.05)
	check(int(game.campaign.state.beacon_charge) == 1 and not events.is_active(), "Ignoring the sparks burns a night of fuel")
	check(events.start("sparks"), "Sparks can start again")
	game.player.position = generator.position + Vector3(0, .3, .8)
	game.interaction_cooldown = 0
	check(game.attempt_interaction(generator) and not events.is_active() and int(game.campaign.state.beacon_charge) == 1, "Repairing in time keeps the fuel")
	check(events.start("shoal"), "Shoal event can start")
	var rare := 0
	for i in 40:
		if events.species_bonus() != "perch":
			rare += 1
	check(rare > 25, "Shoal makes rare fish much more likely")
	events.on_fish_caught()
	check(not events.is_active(), "A catch during the shoal resolves it")
	game.player.position = Vector3(3, 1.2, 4)
	check(events.start("fog") and is_instance_valid(events.fog_enemy) and events.fog_enemy.day_event, "Fog brings a daytime shadow")
	check(events.keeps_day_enemies(), "Daytime cleanup keeps the fog shadow alive")
	var scrap_fog := int(game.expedition.state.scrap)
	events.fog_enemy.burn(500)
	await frames(50)
	events.advance(.1)
	check(not events.is_active() and int(game.expedition.state.scrap) == scrap_fog + 2, "Burning the fog shadow rewards the keeper")

	# --- Ночная подсказка первого дня ведёт к койке ---
	game.day = 1
	game.campaign.state.day = 1
	game.campaign.ensure_day()
	game.campaign.state.night = true
	game.campaign.state.event_done = true
	game.campaign.state.night_clock = 30.0
	game.set_building_interior("")
	check(String(overlay.objective().text).contains("Войдите в хижину"), "After the first night outside, the goal says to enter the cabin")
	game.set_building_interior("cabin")
	check(String(overlay.objective().text).contains("койки"), "Inside the cabin, the goal points at the bunk")
	game.set_building_interior("")
	game.campaign.state.night = false
	game.day = 4
	game.campaign.state.day = 4
	game.campaign.ensure_day()

	# --- Сохранение новых систем ---
	game.lantern_beam.charge = 42
	raids.barricade_hp = 63
	check(game.save_game(true), "Game saves with the new systems")
	game.lantern_beam.charge = 100
	raids.barricade_hp = 100
	check(game.load_game() and roundi(game.lantern_beam.charge) == 42 and roundi(raids.barricade_hp) == 63, "Beam charge and barricade damage survive a reload")

	print("DYNAMICS_CHECKS ", checks, " failures ", failures)
	quit(1 if failures > 0 else 0)
