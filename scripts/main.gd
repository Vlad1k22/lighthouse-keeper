extends Node3D
## Выживание, календарь экспедиции, взаимодействия и сохранения.
const HUD = preload("res://scripts/hud.gd")
const SOUND = preload("res://scripts/soundscape.gd")
const SHADOW_SCENE = preload("res://scenes/shadow.tscn")
const Geo = preload("res://scripts/geometry.gd")
const FISHING = preload("res://scripts/fishing.gd")
const PROVISIONS = preload("res://scripts/provisions.gd")
const SURVIVAL = preload("res://scripts/survival_supplies.gd")
const RADIO_TUNER = preload("res://scripts/radio_tuner.gd")
const EXPEDITION = preload("res://scripts/expedition.gd")
const CAMPAIGN = preload("res://scripts/campaign.gd")
const FIRST_SHIFT_DEMO = preload("res://scripts/first_shift_demo.gd")
const PREFERENCES = preload("res://scripts/game_preferences.gd")
const EXTRAS = preload("res://scripts/game_extras.gd")
const LIGHTHOUSE_INTERIOR = preload("res://scripts/lighthouse_interior.gd")
const BUILDING_INTERIORS = preload("res://scripts/building_interiors.gd")
var expedition := EXPEDITION.new()
var survival := SURVIVAL.new()
var campaign := CAMPAIGN.new()
var first_shift_demo := FIRST_SHIFT_DEMO.new()
var preferences := PREFERENCES.new()
var extras := EXTRAS.new()
var lighthouse_interior := LIGHTHOUSE_INTERIOR.new()
var building_interiors := BUILDING_INTERIORS.new()
var checkpoints_enabled := true
var loading_save := false
var last_run_won := false
var checkpoint_path := "user://campaign_day_checkpoint.json"

@export var hours_per_second: float = 0.055
@onready var player: CharacterBody3D = $Keeper
@onready var world: Node3D = $World
@onready var camera: Camera3D = $IsometricCamera
var hud: CanvasLayer
var sound: Node
var stations: Array = []
var nearest_station: Area3D
var enemies: Array = []
var inventory := {"fuel": 0, "wood": 0, "fish": 0, "food": 1}
var fish_items: Array[Dictionary] = []
var food_items: Array[Dictionary] = [PROVISIONS.ration()]
var selected_fish := 0
var selected_food := 0
var health := 100.0
var hunger := 85.0
var sanity := 100.0
var hour := 16.5
var day := 1
var fuel_found := false
var lighthouse_on := false
var barricade_built := false
var playing := false
var paused := false
var finished := false
var was_night := false
var night_spawned := false
var overview := false
var fishing := FISHING.new()
var interaction_cooldown := 0.0
var message := ""
var message_time := 0.0
var spawn_clock := 0.0
var save_path := "user://first_shift_save.json"
var camera_focus := Vector3(-5, 2, 3)
var camera_zoom := 42.0
var target_zoom := 25.0
var beacon: Node3D
var barricade: Node3D
var capture_path := ""
var capture_frames := 0
var coastal_life: Node3D
var journal_open := false
var journal_page := 0
var journal_entries: Array[String] = []
var camera_shake := 0.0
const STORIES := {
	"crew_log": {"title": "Журнал экипажа «Северного»", "text": "На последней странице под слоем соли видны четыре подписи.\n\nЛюдкевич Владислав\nКотельников Константин\nВиговский Андрей\nАртамонов Артем\n\nГруппа ИУК2-53Б · 2026\n\nВнизу карандашом приписано: «Если этот лист нашёлся, значит, катер снова на плаву»."},
	"sign": {"title": "01 / Надпись на тропе", "text": "«Если услышишь шаги за собой — не гаси свет».\n\nБуквы вырезаны неровно, словно кто-то торопился. Под последней строчкой — маленький рисунок маяка.\n\nВы узнаёте этот почерк. Так вы подписывали свои вещи ещё до приезда на остров. Но эту табличку вы видите впервые."},
	"radio": {"title": "02 / Сигнал с берега", "text": "Частота 104.6. Сквозь треск прорывается голос:\n\n«Северный, ответьте. Последний катер ушёл три недели назад. Больше никто не высаживался на острове. Повторяю: вы там один».\n\nПередача обрывается. На секунду в динамике слышно ваше собственное дыхание — с небольшим опозданием.\n\nКто тогда ходит по лесу после заката?"}
}

func _ready() -> void:
	first_shift_demo.game = self
	survival.game = self
	survival.reset()
	extras.game = self
	preferences.game = self
	preferences.load_preferences()
	# Keep application/config/name stable so existing user:// saves remain visible.
	DisplayServer.window_set_title("Смотритель маяка | Путь с острова")
	fishing.resolved.connect(on_fishing_resolved)
	beacon = world.find_child("Lighthouse", true, false)
	lighthouse_interior.name = "LighthouseInterior"
	add_child(lighthouse_interior)
	building_interiors.name = "BuildingInteriors"
	add_child(building_interiors)
	coastal_life = world.get_node("CoastalLife")
	preload("res://scripts/ship_visual.gd").install(world.get_node("NorthernCoast/CoastalVessel"))
	preload("res://scripts/cabin_visual.gd").install(world.get_node("IslandGeometry/KeeperCabin"))
	preload("res://scripts/radio_visual.gd").install(world.get_node("NorthernCoast"))
	building_interiors.setup(world)
	expedition.setup(self)
	campaign.setup(self)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-") or argument.begins_with("--demo-") or argument=="--no-checkpoints":checkpoints_enabled=false
	stations = get_tree().get_nodes_in_group("interactables")
	sound = Node.new()
	sound.set_script(SOUND)
	add_child(sound)
	player.stepped.connect(sound.footstep)
	var listener := AudioListener3D.new()
	listener.name = "HorrorListener"
	listener.position.y = 1.4
	player.add_child(listener)
	listener.make_current()
	hud = CanvasLayer.new()
	hud.set_script(HUD)
	add_child(hud)
	camera.position = camera_focus + Vector3(29, 34, 40)
	camera.look_at(camera_focus)
	camera.size = camera_zoom
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--save-path="):
			save_path = argument.trim_prefix("--save-path=")
	if "--preview-fishing" in OS.get_cmdline_user_args() or "--demo-fishing" in OS.get_cmdline_user_args():
		start_shift()
		player.position = world.get_node("Station_fish").position + Vector3(0, 0.3, 0)
		update_nearest()
		if "--preview-fishing" in OS.get_cmdline_user_args():
			start_fishing()
			fishing.advance(2.5, false)
			fishing.press_action()
		else:
			notify("Причал. Нажмите E для рыбалки; Пробел или ЛКМ — управление.", 12)
	elif "--preview-day" in OS.get_cmdline_user_args():
		start_shift()
		overview = true
		hour = 16.8
		fuel_found = true
		lighthouse_on = true
		beacon.set_powered(true)
		notify("Маяк снова горит. Подготовьте убежище к ночи.")
	elif "--preview-journal" in OS.get_cmdline_user_args():
		start_shift()
		overview = true
		unlock_story("radio")
	elif "--preview-night" in OS.get_cmdline_user_args():
		start_shift()
		overview = true
		hour = 22
		fuel_found = true
		lighthouse_on = true
		barricade_built = true
		build_barricade()
		beacon.set_powered(true)
		coastal_life.rain_strength = 0.7
	elif "--demo-expedition" in OS.get_cmdline_user_args() or "--preview-harbor" in OS.get_cmdline_user_args() or "--preview-map" in OS.get_cmdline_user_args() or "--preview-vessel" in OS.get_cmdline_user_args():
		start_demo()
		if "--preview-vessel" in OS.get_cmdline_user_args():
			player.position = Vector3(-33,1.3,-21)
			camera_focus = player.position
			target_zoom = 23
		if "--preview-map" in OS.get_cmdline_user_args():
			expedition.open_board()
	elif "--preview-play" in OS.get_cmdline_user_args():
		start_shift()
		hour = 18.3
		lighthouse_on = true
		fuel_found = true
		beacon.set_powered(true)
		notify("Маяк снова горит. Подготовьте убежище к ночи.")
	if not capture_path.is_empty():
		if "--preview-vessel" in OS.get_cmdline_user_args():
			camera_focus = player.position+Vector3(0,1,0)
			camera_zoom = 23
		elif "--preview-harbor" in OS.get_cmdline_user_args() or "--preview-map" in OS.get_cmdline_user_args():
			camera_focus = Vector3(-27,2,-24)
			camera_zoom = 32
			target_zoom = 32
		elif "--preview-play" in OS.get_cmdline_user_args() or "--preview-fishing" in OS.get_cmdline_user_args():
			camera_focus = player.position + Vector3(0, 1, 0)
			camera_zoom = 25
		else:
			camera_focus = Vector3(-6, 2, -16) if playing else Vector3(-5, 2, 3)
			camera_zoom = 78 if playing else 42
		camera.position = camera_focus + Vector3(29, 34, 40)
		camera.look_at(camera_focus)
		camera.size = camera_zoom
	update_atmosphere()

func start_or_resume() -> void:
	if playing and paused and not finished:
		start_shift()
	elif first_shift_demo.active() and finished:
		if last_run_won:
			return_to_title()
		else:
			start_first_shift_demo()
	elif finished and not last_run_won and campaign.enabled and FileAccess.file_exists(checkpoint_path):
		retry_day()
	else:
		first_shift_demo.reset()
		campaign.enabled = true
		checkpoints_enabled = true
		playing = false
		start_shift()

func start_shift() -> void:
	if playing and paused and not finished:
		paused = false
		journal_open = false
		player.enabled = not fishing.is_open()
		hud.show_game()
		return
	fishing.close()
	inventory = {"fuel": 0, "wood": 0, "fish": 0, "food": 1}
	fish_items.clear()
	food_items = [PROVISIONS.ration()]
	selected_fish = 0
	selected_food = 0
	health = 100
	hunger = 85
	sanity = 100
	hour = 7.0 if campaign.enabled else 16.5
	day = 1
	fuel_found = false
	lighthouse_on = false
	barricade_built = false
	beacon.set_powered(false)
	expedition.reset()
	campaign.reset()
	survival.reset()
	expedition.reset_ship()
	expedition.update_visuals()
	reset_world_state()
	set_lighthouse_interior(false)
	set_building_interior("")
	building_interiors.set_warehouse(false)
	player.position = Vector3(3, 1.2, 4)
	player.reset_motion()
	player.stamina = 100
	player.lantern_on = true
	playing = true
	paused = false
	finished = false
	last_run_won = false
	journal_open = false
	journal_entries.clear()
	coastal_life.weather_mode = 0
	was_night = false
	night_spawned = false
	fishing.casts = 0
	player.enabled = true
	overview = false
	hud.show_game()
	notify("День 1. Найдите канистру и запустите маяк. Следующая цель отмечена на карте M.", 10)
	save_checkpoint()

func reset_world_state() -> void:
	clear_enemies()
	world.find_child("FuelCan", true, false).show()
	world.find_child("FuelHandle", true, false).show()
	if is_instance_valid(barricade):
		barricade.queue_free()
		barricade = null
	for station in stations:
		if station.station_id == "fuel":
			station.remaining = 1
		elif station.station_id == "wood":
			station.remaining = 9
		for child in station.get_children():
			if child is Label3D:
				child.show()

func _process(delta: float) -> void:
	expedition.advance(delta)
	if fishing.is_open() and playing and not paused and not finished:
		var old_phase := fishing.phase
		var held := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		fishing.advance(delta, held)
		if old_phase != fishing.phase and fishing.phase == FISHING.Phase.BITE:
			sound.interact("fish")
	var active := playing and not paused and not finished and not fishing.is_open() and not expedition.sailing
	if active:
		enemies = enemies.filter(func(enemy): return is_instance_valid(enemy))
		if campaign.enabled:
			if not first_shift_demo.awaiting_contact():
				campaign.advance(delta*hours_per_second/0.055)
		else:
			hour += delta * hours_per_second
			if hour >= 24:
				hour -= 24
				day += 1
		survival.advance(delta)
		hunger = maxf(0, hunger - delta * (0.025 if campaign.enabled else 0.11))
		if hunger <= 0:
			health -= delta * 0.8
		sanity = clampf(sanity + delta * (-0.14 if is_night() and not is_safe(player.position) else 0.04), 0, 100)
		if sanity <= 0:
			health -= delta * 0.3
		if is_night():
			was_night = true
			spawn_clock += delta
			if not night_spawned:
				spawn_night()
			elif spawn_clock > 45 and enemies.size() < 4:
				spawn_shadow(Vector3(-13, 1.5, 4))
				spawn_clock = 0
		else:
			clear_enemies()
			night_spawned = false
			if hour >= 6 and hour < 20:
				expedition.dawn()
		if health <= 0:
			finish_shift(false)
		interaction_cooldown = maxf(0, interaction_cooldown - delta)
		update_nearest()
		if player.position.y < -2:
			player.position = Vector3(3, 1.3, 4)
			player.reset_motion()
			take_damage(10)
			notify("Течение слишком сильное. Вы вернулись к хижине.")
	message_time = maxf(0, message_time - delta)
	update_atmosphere()
	sound.set_ambience(coastal_life.night_strength, coastal_life.rain_strength)
	sound.set_story_silence(campaign.enabled and campaign.state.night and campaign.entry().night.kind=="silence")
	var ship: Node3D = world.get_node("NorthernCoast/CoastalVessel")
	sound.set_engine(player.position.distance_to(ship.position+Vector3(0,1,1)), expedition.state.engine and playing and not finished and not paused)
	building_interiors.update_state(player.position, playing and not finished, lighthouse_interior.active or not building_interiors.active.is_empty(), expedition.sailing, expedition.state.tools, expedition.state.signal)
	building_interiors.update_first_watch(campaign.first_window_strength(), float(campaign.state.night_clock))
	update_camera(delta)
	hud.refresh()
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 45:
			capture_preview.call_deferred()

func update_camera(delta: float) -> void:
	var focus := Vector3(-5, 2, 3)
	var zoom := 42.0
	var offset := Vector3(29, 34, 40)
	if playing and not finished:
		focus = Vector3(-6, 2, -16) if overview else player.position + Vector3(0, 1.0, 0)
		zoom = 78.0 if overview else target_zoom
	if lighthouse_interior.active:
		focus = player.position + Vector3.UP*.75
		zoom = LIGHTHOUSE_INTERIOR.ZOOM
		offset = LIGHTHOUSE_INTERIOR.LOOK_OFFSET
		lighthouse_interior.update_cutaway(player.position, lighthouse_on, beacon.get_node("BeamPivot").rotation.y)
	elif not building_interiors.active.is_empty() or building_interiors.warehouse_open:
		focus = building_interiors.camera_focus(player.position)
		zoom = building_interiors.zoom()
		offset = BUILDING_INTERIORS.LOOK_OFFSET
	camera_focus = camera_focus.lerp(focus, 1.0 - exp(-delta * 4))
	camera_zoom = lerpf(camera_zoom, zoom, 1.0 - exp(-delta * 3))
	camera.position = camera_focus + offset
	camera.look_at(camera_focus)
	camera.size = camera_zoom
	if camera_shake > 0:
		camera_shake = maxf(0, camera_shake - delta * 1.8)
		camera.h_offset = sin(Time.get_ticks_msec() * 0.04) * camera_shake * 0.12
		camera.v_offset = cos(Time.get_ticks_msec() * 0.033) * camera_shake * 0.08
	else:
		camera.h_offset = 0
		camera.v_offset = 0

func set_lighthouse_interior(inside: bool) -> void:
	lighthouse_interior.set_active(inside)
	player.indoors = inside
	camera.environment = lighthouse_interior.room_env if inside else null
	world.visible = not inside
	overview = false

func lighthouse_action() -> bool:
	var inside := lighthouse_interior.active
	if player.jump_in_progress:
		return inside
	if lighthouse_interior.near_door(player.position):
		set_lighthouse_interior(not inside)
		player.position = LIGHTHOUSE_INTERIOR.OUTSIDE_DOOR if inside else LIGHTHOUSE_INTERIOR.ORIGIN + LIGHTHOUSE_INTERIOR.INSIDE_DOOR + Vector3.UP*.045
		player.reset_motion()
		camera_focus = player.position + Vector3.UP*.75
		camera_zoom = target_zoom if inside else LIGHTHOUSE_INTERIOR.ZOOM
		update_camera(0.0)
		update_nearest()
		sound.interact("wood")
		interaction_cooldown = .28
		notify("Вы вышли к маяку." if inside else "Поднимитесь по лестнице, чтобы осмотреть линзу.", 3.0)
		return true
	if inside and lighthouse_interior.near_optic(player.position):
		player.play_gesture("interact")
		if not lighthouse_on or campaign.intercept("lighthouse_lens") != 1:
			notify("Линза вращается. Свет маяка виден с моря." if lighthouse_on else "Линза погасла. Питание подаётся от генератора снаружи.")
	return inside

func map_player_position() -> Vector3:
	if not building_interiors.active.is_empty():
		return building_interiors.exit_at(building_interiors.active)
	return LIGHTHOUSE_INTERIOR.OUTSIDE_DOOR if lighthouse_interior.active else player.position

func set_building_interior(id: String) -> void:
	if id != "cabin":
		extras.stop_record()
	building_interiors.set_room(id)
	if id == "cabin":
		extras.install_cabin(building_interiors.instances[id])
	var inside := not id.is_empty()
	player.indoors = inside
	camera.environment = building_interiors.room_env if inside else null
	world.visible = not inside
	overview = false

func building_door_action() -> bool:
	if expedition.sailing or fishing.is_open() or player.jump_in_progress:
		return false
	var id := building_interiors.door_at(player.position)
	if id.is_empty():
		return false
	if building_interiors.active.is_empty():
		set_building_interior(id)
		player.position = building_interiors.spawn_at(id)
		place_camera_after_door(building_interiors.camera_focus(player.position), building_interiors.zoom())
	else:
		exit_building()
	sound.interact("wood")
	interaction_cooldown = .28
	return true

func exit_building() -> void:
	var at := building_interiors.exit_at(building_interiors.active)
	set_building_interior("")
	player.position = at
	place_camera_after_door(at + Vector3.UP, target_zoom)

func place_camera_after_door(focus: Vector3, zoom: float) -> void:
	player.reset_motion()
	camera_focus = focus
	camera_zoom = zoom
	update_camera(0.0)
	update_nearest()

func update_atmosphere() -> void:
	var night := 0.0
	if hour >= 17:
		night = smoothstep(17.0, 21.0, hour)
	elif hour < 7:
		night = 1.0 - smoothstep(5.0, 7.0, hour)
	var env: Environment = world.get_node("CoastalAtmosphere").environment
	env.ambient_light_energy = lerpf(0.48, 0.18, night)
	env.ambient_light_color = Color("9da8a2").lerp(Color("657c8e"), night)
	env.fog_light_color = Color("263435").lerp(Color("0d1921"), night)
	env.fog_density = lerpf(0.0045, 0.009, night)
	env.background_color = Color("17282c").lerp(Color("08131c"), night)
	var sun: DirectionalLight3D = world.get_node("Sun")
	sun.light_energy = lerpf(0.90, 0.15, night)
	sun.light_color = Color("bac6c2").lerp(Color("778ca4"), night)
	world.get_node("Ocean").material_override.set_shader_parameter("night_factor", night)
	coastal_life.night_strength = night
	coastal_life.story_storm = campaign.enabled and campaign.state.night and campaign.entry().night.kind in ["storm","last"]
	if campaign.enabled and campaign.state.night and campaign.entry().night.kind in ["silence","double"]:
		env.fog_density += .003

func is_night() -> bool:
	return hour >= 20 or hour < 6

func is_safe(at: Vector3) -> bool:
	if lighthouse_interior.active and lighthouse_interior.contains(at):
		return true
	if building_interiors.contains(building_interiors.active, at):
		at = map_player_position()
	if int(expedition.state.fire_day)>0 and int(expedition.state.fire_day)>=int(expedition.state.last_dawn) and at.distance_to(Vector3(-16,1,-28)) < 6:
		return true
	if lighthouse_on and Vector2(at.x + 9, at.z + 7).length() < 8:
		return true
	return barricade_built and Vector2(at.x - 5, at.z - 1).length() < 6.0

func current_objective() -> String:
	if day > 1:
		return expedition.objective()
	if not fuel_found:
		return "Канистра — у ящиков к северо-востоку от хижины."
	if not lighthouse_on:
		return "Отнесите топливо к генератору возле маяка."
	if not barricade_built:
		return "Соберите 3 древесины в лесу. Затем идите к верстаку."
	return "Ночью держитесь света. В хижине можно переждать ночь."

func update_nearest() -> void:
	nearest_station = null
	var best := station_reach()
	for station in stations:
		if lighthouse_interior.active or not station.is_available():
			continue
		var distance := station_distance(station)
		if distance < best:
			best = distance
			nearest_station = station
	for station in stations:
		station.selected = station == nearest_station
		station.quest_target = campaign.enabled and campaign.target_id()==station.station_id

func near_station(id: String) -> Area3D:
	if lighthouse_interior.active:
		return null
	for station in stations:
		if station.station_id==id and station.is_available() and station_distance(station)<=station_reach():
			return station
	return null

func station_reach() -> float:
	return 2.5 if building_interiors.active.is_empty() else 1.18

func station_distance(station: Area3D) -> float:
	if not building_interiors.active.is_empty():
		return building_interiors.station_distance(station.station_id, player.position)
	return Vector2(player.position.x - station.position.x, player.position.z - station.position.z).length()

func attempt_interaction(station: Area3D) -> bool:
	if not playing or paused or finished or fishing.is_open() or expedition.sailing or not is_instance_valid(station):
		return false
	if player.jump_in_progress:
		return false
	if station_distance(station) > station_reach() or not station.is_available():
		return false
	var demo_result := first_shift_demo.intercept(station.station_id)
	if demo_result >= 0:
		return demo_result == 1
	var handled: int = campaign.intercept(station.station_id)
	if handled>=0:return handled==1
	if station.station_id in EXPEDITION.IDS:
		var succeeded: bool = expedition.interact(station.station_id)
		if expedition.sailing and building_interiors.active == "ship":
			exit_building()
		campaign.observe(station.station_id,succeeded)
		return succeeded
	match station.station_id:
		"fuel":
			inventory.fuel += 1
			fuel_found = true
			station.consume()
			world.find_child("FuelCan", true, false).hide()
			world.find_child("FuelHandle", true, false).hide()
			notify("Канистра в рюкзаке. Генератор ждёт возле маяка.")
			feedback(station.position, "+ ТОПЛИВО")
		"beacon":
			if lighthouse_on:
				notify("Маяк работает. Его свет отгоняет тени.")
				return false
			if inventory.fuel < 1 and (not campaign.enabled or int(campaign.state.beacon_charge)<=0):
				notify("Генератору нужно топливо. Проверьте ящики на тропе.")
				return false
			if not campaign.enabled or int(campaign.state.beacon_charge)<=0:
				inventory.fuel -= 1
				if campaign.enabled:campaign.state.beacon_charge = 3
			lighthouse_on = true
			beacon.set_powered(true)
			notify("Маяк включён. Запас топлива: %d ночи. M — задачи дня." % int(campaign.state.beacon_charge) if campaign.enabled else "Маяк заправлен до утра. Собирайте припасы и выполняйте план дня. M — карта.")
			feedback(station.position, "МАЯК ЗАЖЖЁН")
		"wood":
			inventory.wood += 1
			station.consume()
			notify("Древесина +1. Для укрепления нужно 3.")
			feedback(station.position, "+1 ДРЕВЕСИНА")
		"workbench":
			if barricade_built:
				notify("Укрепление готово. Хижина защищает от теней.")
				return false
			if inventory.wood < 3:
				notify("Нужно 3 древесины. Валежник находится на лесной тропе.")
				return false
			inventory.wood -= 3
			barricade_built = true
			build_barricade()
			notify("Хижина укреплена. Подготовьтесь к ночи: рыба, еда и фонарь.")
			feedback(station.position, "УКРЫТИЕ ГОТОВО")
		"fish":
			start_fishing()
		"cook":
			if fish_items.is_empty():
				notify("Сначала поймайте рыбу на причале.")
				return false
			var cooked := fish_items[selected_fish].duplicate(true)
			fish_items.remove_at(selected_fish)
			food_items.append(cooked)
			selected_food = food_items.size() - 1
			sync_provisions()
			var benefit := PROVISIONS.bonuses(cooked)
			notify("Готово: %s. R — съесть: +%d здоровья, +%d сытости." % [PROVISIONS.label(cooked), benefit.health, benefit.hunger])
			feedback(station.position, "+1 ЕДА")
		"shelter":
			return expedition.sleep()
		"note":
			unlock_story("sign")
		"radio":
			unlock_story("radio")
			sound.radio_signal()
	if station.station_id != "radio":
		sound.interact(station.station_id)
	interaction_cooldown = 0.35
	campaign.observe(station.station_id,true)
	return true

func start_fishing() -> void:
	fishing.begin()
	player.enabled = false
	player.velocity = Vector3.ZERO
	player.set_fishing_pose(true)
	notify("Забрасываем удочку. Дождитесь поклёвки.")

func on_fishing_resolved(caught: bool) -> void:
	if caught:
		fish_items.append(PROVISIONS.fish_item(str(fishing.fish.id), fishing.weight))
		sync_provisions()
		sound.interact("fish")
		notify("Улов: %s! Приготовьте рыбу на печи возле хижины." % str(fishing.fish.name).to_lower())
	else:
		notify("Рыба ушла. На причале можно попробовать снова.")

func close_fishing() -> void:
	var cancelled := fishing.phase != FISHING.Phase.RESULT
	fishing.close()
	player.set_fishing_pose(false)
	player.enabled = playing and not paused and not finished
	interaction_cooldown = 0.35
	if cancelled:
		notify("Вы смотали леску. Улов не получен.")

func build_barricade() -> void:
	if is_instance_valid(barricade):
		return
	barricade = Node3D.new()
	barricade.name = "BuiltBarricade"
	barricade.position = Vector3(4.8, 1, 5.3)
	add_child(barricade)
	for x in [-1.6, 0.0, 1.6]:
		Geo.box(barricade, "Post", Vector3(x, 0.7, 0), Vector3(0.16, 1.4, 0.2), Color("8d7956"), true)
	for y in [0.5, 1.1]:
		Geo.box(barricade, "Reinforcement", Vector3(0, y, 0), Vector3(3.8, 0.18, 0.18), Color("aa8e62"), true)
	var brace := Geo.box(barricade, "DiagonalBrace", Vector3(0, 0.8, 0.12), Vector3(3.6, 0.12, 0.12), Color("756449"))
	brace.rotation.z = 0.2

func spawn_night() -> void:
	night_spawned = true
	spawn_clock = 0
	if campaign.enabled and campaign.state.night:
		campaign.spawn_threats()
		return
	for at in [Vector3(-11, 1.5, 5), Vector3(0, 1.5, -10), Vector3(14, 1.5, 9)]:
		spawn_shadow(at)
	if day>1:
		for at in [Vector3(-8,1.5,-31),Vector3(14,1.5,-27)]:
			spawn_shadow(at)
	notify("На острове темнеет. Фонарь и свет маяка отгоняют тени.", 8)

func spawn_shadow(at: Vector3, kind := "shadow") -> void:
	var enemy := SHADOW_SCENE.instantiate()
	enemy.position = at
	enemy.keeper = player
	enemy.game = self
	enemy.kind = kind
	add_child(enemy)
	enemies.append(enemy)

func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

func take_damage(amount: float) -> void:
	health = maxf(0, health - amount)
	player.play_gesture("hit", .36)
	hud.danger.color.a = 0.22
	camera_shake = 1.0
	notify("Тень рядом! Включите фонарь или бегите к свету.")

func eat() -> bool:
	if fishing.is_open():
		return false
	if food_items.is_empty():
		notify("В рюкзаке нет еды. Причал и печь помогут приготовить ужин.")
		return false
	var meal := food_items[selected_food]
	var benefit := PROVISIONS.bonuses(meal)
	survival.ate(meal)
	var previous_health := health
	var previous_hunger := hunger
	food_items.remove_at(selected_food)
	sync_provisions()
	hunger = minf(100, hunger + benefit.hunger)
	health = minf(100, health + benefit.health)
	notify("Съедено: %s. Здоровье +%d, сытость +%d." % [PROVISIONS.label(meal), roundi(health - previous_health), roundi(hunger - previous_hunger)])
	sound.interact()
	return true

func sync_provisions() -> void:
	inventory.fish = fish_items.size()
	inventory.food = food_items.size()
	selected_fish = clampi(selected_fish, 0, maxi(0, fish_items.size() - 1))
	selected_food = clampi(selected_food, 0, maxi(0, food_items.size() - 1))

func select_provision(cooked: bool) -> void:
	var items := food_items if cooked else fish_items
	if items.is_empty():
		notify("Готовой еды нет." if cooked else "Улова пока нет. Попробуйте рыбалку на причале.")
		return
	if cooked:
		selected_food = (selected_food + 1) % items.size()
	else:
		selected_fish = (selected_fish + 1) % items.size()
	var item := items[selected_food if cooked else selected_fish]
	var benefit := PROVISIONS.bonuses(item)
	notify("%s: %s. После еды: +%d здоровья, +%d сытости." % ["Еда" if cooked else "Рыба для готовки", PROVISIONS.label(item), benefit.health, benefit.hunger])

func notify(content: String, duration: float = 5.0) -> void:
	message = content
	message_time = duration

func feedback(at: Vector3, content: String) -> void:
	if not building_interiors.active.is_empty():
		at = player.position
	var label := Label3D.new()
	label.text = content
	label.position = at + Vector3(0, 2.3, 0)
	label.font_size = 32
	label.pixel_size = 0.009
	label.modulate = Color("ffe0a0")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.8, 1.1)
	tween.tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func unlock_story(id: String) -> void:
	if id not in journal_entries:
		journal_entries.append(id)
	journal_page = journal_entries.find(id)
	open_journal()

func open_journal() -> void:
	if fishing.is_open():
		return
	journal_open = true
	paused = true
	player.enabled = false
	if campaign.enabled and "c:code" in journal_entries:journal_page=journal_entries.find("c:code")
	if first_shift_demo.awaiting_contact() and FIRST_SHIFT_DEMO.LOG_ID in journal_entries:
		journal_page = journal_entries.find(FIRST_SHIFT_DEMO.LOG_ID)
	refresh_journal()

func open_journal_entry(id: String) -> void:
	open_journal()
	journal_page = journal_entries.find(id)
	refresh_journal()

func refresh_journal() -> void:
	if journal_entries.is_empty():
		hud.show_journal("Журнал смотрителя", "На острове слишком тихо.\n\nОсмотрите табличку на тропе к маяку и проверьте радиоприёмник у западной стены хижины. Здесь должны остаться следы тех, кто дежурил до вас.", "НАХОДКИ  /  0 ИЗ 2")
	else:
		journal_page = posmod(journal_page, journal_entries.size())
		var id: String = journal_entries[journal_page]
		var entry: Dictionary = STORIES.get(id,RADIO_TUNER.ARCHIVE.get(id,{}))
		if entry.is_empty():
			entry = campaign.journal_entry(id)
		if id == FIRST_SHIFT_DEMO.LOG_ID and first_shift_demo.active():
			entry = FIRST_SHIFT_DEMO.LOG
		if entry.is_empty():return
		hud.show_journal(entry.title, entry.text, "НАХОДКИ  /  %d ИЗ %d" % [journal_page + 1, journal_entries.size()])

func turn_journal_page(direction: int) -> void:
	journal_page += direction
	refresh_journal()

func close_journal() -> void:
	journal_open = false
	paused = false
	player.enabled = not fishing.is_open()
	hud.show_game()

func finish_shift(won: bool) -> void:
	fishing.close()
	finished = true
	last_run_won = won
	player.enabled = false
	if first_shift_demo.active():
		hud.show_menu("demo_win" if won else "demo_loss")
	else:
		hud.show_menu("win" if won else "loss")

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if hud.fieldwork.visible:
			hud.fieldwork.handle(event)
			get_viewport().set_input_as_handled()
			return
		if hud.tuner.visible:
			if event.pressed and not event.echo:
				hud.tuner.handle(event.physical_keycode)
			get_viewport().set_input_as_handled()
			return
	if hud.salvage.visible and event is InputEventKey:
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE: hud.salvage.cancel()
				KEY_SPACE: hud.salvage.strike()
		get_viewport().set_input_as_handled()
		return
	if hud.backpack.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE,KEY_B]:
		hud.backpack.close()
		get_viewport().set_input_as_handled()
		return
	if hud.settings_panel.visible and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		hud.settings_panel.close()
		get_viewport().set_input_as_handled()
		return
	if first_shift_demo.is_open() and event is InputEventKey:
		if event.pressed and not event.echo:
			first_shift_demo.handle_key(event.physical_keycode)
		get_viewport().set_input_as_handled()
		return
	if campaign.code_open() and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		campaign.close_code()
		get_viewport().set_input_as_handled()
		return
	if not fishing.is_open():
		return
	var action := false
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				close_fishing()
			elif event.physical_keycode in [KEY_SPACE, KEY_E]:
				action = true
	elif event is InputEventMouseButton:
		action = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if action:
		if fishing.phase == FISHING.Phase.RESULT and fishing.phase_time > 0.35:
			close_fishing()
		else:
			fishing.press_action()
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if hud.settings_panel.visible or hud.backpack.visible or hud.salvage.visible or hud.fieldwork.visible or hud.tuner.visible or fishing.is_open() or expedition.sailing:
		return
	if event is InputEventMouseButton and event.pressed and playing:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = maxf(18, target_zoom - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = minf(38, target_zoom + 2)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if campaign.code_open():
		if event.physical_keycode == KEY_ESCAPE:campaign.close_code()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(expedition.board) and expedition.board.visible:
		if event.physical_keycode in [KEY_ESCAPE, KEY_E, KEY_M]:
			expedition.close_board()
		get_viewport().set_input_as_handled()
		return
	if journal_open:
		if event.physical_keycode in [KEY_ESCAPE, KEY_E, KEY_J]:
			close_journal()
		elif event.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
			turn_journal_page(-1 if event.physical_keycode == KEY_LEFT else 1)
		elif event.physical_keycode in [KEY_UP, KEY_DOWN]:
			hud.scroll_journal(-1 if event.physical_keycode == KEY_UP else 1)
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and playing and not finished:
		paused = not paused
		player.enabled = not paused
		if paused:
			hud.show_menu("pause")
		else:
			hud.show_game()
	if not playing or paused or finished:
		return
	match event.physical_keycode:
		KEY_M:
			expedition.open_board()
		KEY_B:
			hud.backpack.open()
		KEY_G:
			if is_instance_valid(nearest_station) and nearest_station.station_id in ["wood","north_wood","depot"]:
				if not hud.fieldwork.open_resource(nearest_station):
					notify("Особый сбор пока недоступен. Проверьте обычное действие на E.")
			else:
				hud.salvage.open()
		KEY_K:
			hud.fieldwork.open_kitchen()
		KEY_U:
			hud.tuner.open_scan()
		KEY_H:
			if survival.can_refill():
				survival.refill()
			else:
				survival.drink()
		KEY_E:
			if interaction_cooldown <= 0:
				if not lighthouse_action() and not building_door_action() and not extras.interact() and attempt_interaction(nearest_station) and not fishing.is_open() and player.enabled:
					player.play_gesture("interact")
		KEY_SPACE:
			player.request_jump()
		KEY_F:
			player.toggle_lantern()
		KEY_R:
			eat()
		KEY_Q:
			select_provision(true)
		KEY_T:
			select_provision(false)
		KEY_O:
			if not lighthouse_interior.active and building_interiors.active.is_empty() and not building_interiors.warehouse_open:
				overview = not overview
		KEY_J:
			open_journal()
		KEY_V:
			coastal_life.cycle_weather()
			notify("Погода: " + ["автоматически", "дождь", "без дождя"][coastal_life.weather_mode])
		KEY_N:
			if not campaign.enabled:
				hour = 17.0 if is_night() else 22.0
				was_night = false
		KEY_F9:
			save_game()
		KEY_F10:
			load_game()

func save_game(quiet: bool = false) -> bool:
	if first_shift_demo.active():
		if not quiet:notify("Демо проходится отдельно. Сохранения кампании доступны из главного меню.")
		return false
	if not playing or finished or fishing.is_open() or expedition.sailing:
		return false
	var state := {"version": 1, "inventory": inventory, "health": health, "hunger": hunger, "sanity": sanity, "hour": hour, "day": day, "fuel_found": fuel_found, "lighthouse_on": lighthouse_on, "barricade_built": barricade_built, "position": [player.position.x, player.position.y, player.position.z], "wood_remaining": 9, "was_night": was_night}
	state["journal"] = journal_entries
	state["weather_mode"] = coastal_life.weather_mode
	state["version"] = 5
	state["calendar_days"] = campaign.calendar_days() if campaign.enabled else campaign.LEGACY_DAYS
	state["campaign"] = campaign.serialize()
	state["lantern_on"] = player.lantern_on
	state["inside_lighthouse"] = lighthouse_interior.active
	state["interior_room"] = building_interiors.active
	state["expedition"] = expedition.state
	state["survival"] = survival.save_state()
	state["fish_items"] = fish_items
	state["food_items"] = food_items
	state["selected_fish"] = selected_fish
	state["selected_food"] = selected_food
	state["fishing_casts"] = fishing.casts
	for station in stations:
		if station.station_id == "wood":
			state.wood_remaining = station.remaining
	if not quiet and campaign.enabled and FileAccess.file_exists(checkpoint_path):
		var checkpoint = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
		if checkpoint_matches(checkpoint):
			checkpoint.erase("day_checkpoint")
			state["day_checkpoint"] = checkpoint
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		notify("Не удалось сохранить смену.")
		return false
	file.store_string(JSON.stringify(state, "\t"))
	if not quiet:
		notify("Смена сохранена. F10 — загрузить.")
		hud.continue_button.show()
	return true

func save_checkpoint() -> void:
	if first_shift_demo.active() or not campaign.enabled or not checkpoints_enabled or loading_save:return
	if DisplayServer.get_name()=="headless" and not checkpoint_path.begins_with("user://automated_"):return
	var original := save_path
	save_path = checkpoint_path
	save_game(true)
	save_path = original

func retry_day() -> bool:
	var original := save_path
	save_path = checkpoint_path
	var restored := load_game()
	save_path = original
	return restored

func saved_calendar(saved: Dictionary) -> int:
	if int(saved.get("version", 0))<5:
		return campaign.LEGACY_DAYS
	return campaign.SHORT_DAYS if int(saved.get("calendar_days", 0))==campaign.SHORT_DAYS else campaign.LEGACY_DAYS

func checkpoint_matches(saved: Variant) -> bool:
	return saved is Dictionary and int(saved.get("day",0))==day and saved_calendar(saved)==campaign.calendar_days()

func load_game() -> bool:
	if first_shift_demo.active():
		notify("Откройте сохранение кампании из главного меню.")
		return false
	if fishing.is_open():
		return false
	if not FileAccess.file_exists(save_path):
		notify("Сохранения пока нет. F9 — сохранить смену.")
		return false
	var state = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not state is Dictionary or int(state.get("version", 0)) not in [1, 2, 3, 4, 5]:
		notify("Файл сохранения не поддерживается.")
		return false
	playing = false
	loading_save = true
	start_shift()
	campaign.select_calendar(saved_calendar(state))
	for key in inventory.keys():
		inventory[key] = int(state.inventory.get(key, 0))
	fish_items = PROVISIONS.restore(state.get("fish_items"), inventory.fish, false)
	food_items = PROVISIONS.restore(state.get("food_items"), inventory.food, true)
	selected_fish = int(state.get("selected_fish", 0))
	selected_food = int(state.get("selected_food", 0))
	fishing.casts = maxi(0, int(state.get("fishing_casts", 0)))
	sync_provisions()
	health = float(state.health)
	hunger = float(state.hunger)
	sanity = float(state.sanity)
	hour = float(state.hour)
	day = clampi(int(state.day),1,campaign.calendar_days())
	fuel_found = bool(state.fuel_found)
	lighthouse_on = bool(state.lighthouse_on)
	barricade_built = bool(state.barricade_built)
	was_night = bool(state.get("was_night", false))
	expedition.restore(state.get("expedition", {}))
	survival.restore(state.get("survival",{}))
	if int(state.get("version",0))<4:campaign.enabled = true
	campaign.restore(state.get("campaign",{}) if int(state.get("version",0))>=4 else {},int(state.get("version",0))<4)
	for entry in state.get("journal", []):
		if entry not in journal_entries and (STORIES.has(entry) or RADIO_TUNER.ARCHIVE.has(entry) or not campaign.journal_entry(str(entry)).is_empty()):
			journal_entries.append(str(entry))
	coastal_life.weather_mode = int(state.get("weather_mode", 0))
	player.position = Vector3(state.position[0], state.position[1], state.position[2])
	if bool(state.get("inside_lighthouse", false)):
		if lighthouse_interior.contains(player.position):
			set_lighthouse_interior(true)
			camera_focus = player.position + Vector3.UP*.75
			camera_zoom = LIGHTHOUSE_INTERIOR.ZOOM
		else:
			player.position = LIGHTHOUSE_INTERIOR.OUTSIDE_DOOR
	else:
		var room_id := str(state.get("interior_room", ""))
		if BUILDING_INTERIORS.ROOMS.has(room_id):
			if building_interiors.contains(room_id, player.position):
				set_building_interior(room_id)
				camera_focus = building_interiors.camera_focus(player.position)
				camera_zoom = building_interiors.zoom()
			else:
				player.position = building_interiors.exit_at(room_id)
	player.reset_motion()
	player.lantern_on = bool(state.get("lantern_on",true))
	beacon.set_powered(lighthouse_on)
	if barricade_built:
		build_barricade()
	for station in stations:
		if station.station_id == "wood":
			station.remaining = int(state.get("wood_remaining", 9))
		if station.station_id == "fuel" and fuel_found:
			station.consume()
			world.find_child("FuelCan", true, false).hide()
			world.find_child("FuelHandle", true, false).hide()
	notify("Смена загружена.")
	loading_save = false
	if campaign.enabled and checkpoints_enabled and (DisplayServer.get_name()!="headless" or checkpoint_path.begins_with("user://automated_")):
		var checkpoint = state.get("day_checkpoint")
		if checkpoint_matches(checkpoint):
			checkpoint.erase("day_checkpoint")
			var checkpoint_file := FileAccess.open(checkpoint_path,FileAccess.WRITE)
			if checkpoint_file!=null:checkpoint_file.store_string(JSON.stringify(checkpoint))
		elif save_path!=checkpoint_path:
			var previous_checkpoint = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path)) if FileAccess.file_exists(checkpoint_path) else {}
			if not checkpoint_matches(previous_checkpoint):save_checkpoint()
	return true

func capture_preview() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(capture_path)
	print("Captured preview: ", capture_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)

func start_first_shift_demo() -> void:
	playing = false
	campaign.enabled = true
	# Mark the episode before start_shift can write a campaign checkpoint.
	first_shift_demo.stage = FIRST_SHIFT_DEMO.Stage.INTRO
	start_shift()
	player.lantern_on = false
	camera_focus = player.position + Vector3.UP
	camera_zoom = target_zoom
	update_camera(0.0)
	first_shift_demo.show_intro()

func return_to_title() -> void:
	first_shift_demo.reset()
	playing = false
	paused = false
	finished = false
	player.enabled = false
	clear_enemies()
	set_lighthouse_interior(false)
	set_building_interior("")
	building_interiors.set_warehouse(false)
	player.position = Vector3(3, 1.2, 4)
	player.reset_motion()
	camera_focus = Vector3(-5, 2, 3)
	camera_zoom = 42.0
	update_camera(0.0)
	hud.show_menu("title")

func start_demo() -> void:
	# Separate demonstration snapshot; never overwrites the player's save.
	first_shift_demo.reset()
	playing = false
	campaign.enabled = false
	checkpoints_enabled = false
	start_shift()
	day = 5
	hour = 14
	fuel_found = true
	lighthouse_on = true
	barricade_built = true
	beacon.set_powered(true)
	build_barricade()
	inventory.wood = 12
	inventory.fuel = 5
	for i in 3: food_items.append(PROVISIONS.ration())
	sync_provisions()
	expedition.state.merge({"tools":true,"battery":true,"signal":true,"pump":true,"last_dawn":5,"scrap":8},true)
	expedition.update_visuals()
	player.position = Vector3(-23,1.3,-21)
	camera_focus = player.position
	camera_zoom = 30
	target_zoom = 30
	notify("Показ нового этапа · день 5. Пройдите по трапу на катер и почините корпус. M — карта и задачи.",12)
