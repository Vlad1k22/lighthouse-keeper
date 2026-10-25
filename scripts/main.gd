extends Node3D
## Контроллер первой смены: задания, время суток, выживание, сохранение.
const HUD = preload("res://scripts/hud.gd")
const SOUND = preload("res://scripts/soundscape.gd")
const SHADOW_SCENE = preload("res://scenes/shadow.tscn")
const Geo = preload("res://scripts/geometry.gd")
const FISHING = preload("res://scripts/fishing.gd")
const PROVISIONS = preload("res://scripts/provisions.gd")

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
	"sign": {"title": "01 / Надпись на тропе", "text": "«Если услышишь шаги за собой — не гаси свет».\n\nБуквы вырезаны неровно, словно кто-то торопился. Под последней строчкой — маленький рисунок маяка.\n\nВы узнаёте этот почерк. Так вы подписывали свои вещи ещё до приезда на остров. Но эту табличку вы видите впервые."},
	"radio": {"title": "02 / Сигнал с берега", "text": "Частота 104.6. Сквозь треск прорывается голос:\n\n«Северный, ответьте. Последний катер ушёл три недели назад. Больше никто не высаживался на острове. Повторяю: вы там один».\n\nПередача обрывается. На секунду в динамике слышно ваше собственное дыхание — с небольшим опозданием.\n\nКто тогда ходит по лесу после заката?"}
}

func _ready() -> void:
	fishing.resolved.connect(on_fishing_resolved)
	beacon = world.find_child("Lighthouse", true, false)
	coastal_life = world.get_node("CoastalLife")
	stations = get_tree().get_nodes_in_group("interactables")
	sound = Node.new()
	sound.set_script(SOUND)
	add_child(sound)
	player.stepped.connect(sound.footstep)
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
	elif "--preview-play" in OS.get_cmdline_user_args():
		start_shift()
		hour = 18.3
		lighthouse_on = true
		fuel_found = true
		beacon.set_powered(true)
		notify("Маяк снова горит. Подготовьте убежище к ночи.")
	if not capture_path.is_empty():
		if "--preview-play" in OS.get_cmdline_user_args() or "--preview-fishing" in OS.get_cmdline_user_args():
			camera_focus = player.position + Vector3(0, 1, 0)
			camera_zoom = 25
		else:
			camera_focus = Vector3(0, 2, 1) if playing else Vector3(-5, 2, 3)
			camera_zoom = 43 if playing else 42
		camera.position = camera_focus + Vector3(29, 34, 40)
		camera.look_at(camera_focus)
		camera.size = camera_zoom
	update_atmosphere()

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
	hour = 16.5
	day = 1
	fuel_found = false
	lighthouse_on = false
	barricade_built = false
	beacon.set_powered(false)
	reset_world_state()
	player.position = Vector3(3, 1.2, 4)
	player.velocity = Vector3.ZERO
	player.stamina = 100
	player.lantern_on = true
	playing = true
	paused = false
	finished = false
	journal_open = false
	journal_entries.clear()
	coastal_life.weather_mode = 0
	was_night = false
	night_spawned = false
	fishing.casts = 0
	player.enabled = true
	overview = false
	hud.show_game()
	notify("Первая смена. Найдите канистру у ящиков на северной тропе.")

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
	if fishing.is_open() and playing and not paused and not finished:
		var old_phase := fishing.phase
		var held := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		fishing.advance(delta, held)
		if old_phase != fishing.phase and fishing.phase == FISHING.Phase.BITE:
			sound.interact("fish")
	var active := playing and not paused and not finished and not fishing.is_open()
	if active:
		enemies = enemies.filter(func(enemy): return is_instance_valid(enemy))
		hour += delta * hours_per_second
		if hour >= 24:
			hour -= 24
			day += 1
		hunger = maxf(0, hunger - delta * 0.11)
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
			if was_night and hour >= 6 and hour < 12:
				finish_shift(lighthouse_on and barricade_built)
		if health <= 0:
			finish_shift(false)
		interaction_cooldown = maxf(0, interaction_cooldown - delta)
		update_nearest()
		if player.position.y < -2:
			player.position = Vector3(3, 1.3, 4)
			player.velocity = Vector3.ZERO
			take_damage(10)
			notify("Течение слишком сильное. Вы вернулись к хижине.")
	message_time = maxf(0, message_time - delta)
	update_atmosphere()
	sound.set_ambience(coastal_life.night_strength, coastal_life.rain_strength)
	update_camera(delta)
	hud.refresh()
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 45:
			capture_preview.call_deferred()

func update_camera(delta: float) -> void:
	var focus := Vector3(-5, 2, 3)
	var zoom := 42.0
	if playing and not finished:
		focus = Vector3(0, 2, 1) if overview else player.position + Vector3(0, 1.0, 0)
		zoom = 43.0 if overview else target_zoom
	camera_focus = camera_focus.lerp(focus, 1.0 - exp(-delta * 4))
	camera_zoom = lerpf(camera_zoom, zoom, 1.0 - exp(-delta * 3))
	camera.position = camera_focus + Vector3(29, 34, 40)
	camera.look_at(camera_focus)
	camera.size = camera_zoom
	if camera_shake > 0:
		camera_shake = maxf(0, camera_shake - delta * 1.8)
		camera.h_offset = sin(Time.get_ticks_msec() * 0.04) * camera_shake * 0.12
		camera.v_offset = cos(Time.get_ticks_msec() * 0.033) * camera_shake * 0.08
	else:
		camera.h_offset = 0
		camera.v_offset = 0

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

func is_night() -> bool:
	return hour >= 20 or hour < 6

func is_safe(at: Vector3) -> bool:
	if lighthouse_on and Vector2(at.x + 9, at.z + 7).length() < 8:
		return true
	return barricade_built and Vector2(at.x - 5, at.z - 1).length() < 6.0

func current_objective() -> String:
	if not fuel_found:
		return "Канистра — у ящиков к северо-востоку от хижины."
	if not lighthouse_on:
		return "Отнесите топливо к генератору возле маяка."
	if not barricade_built:
		return "Соберите 3 древесины в лесу. Затем идите к верстаку."
	return "Ночью держитесь света. В хижине можно переждать ночь."

func update_nearest() -> void:
	nearest_station = null
	var best := 2.5
	for station in stations:
		if not station.is_available():
			continue
		var distance := Vector2(player.position.x - station.position.x, player.position.z - station.position.z).length()
		if distance < best:
			best = distance
			nearest_station = station
	for station in stations:
		station.selected = station == nearest_station

func attempt_interaction(station: Area3D) -> bool:
	if not playing or paused or finished or fishing.is_open() or not is_instance_valid(station):
		return false
	if Vector2(player.position.x - station.position.x, player.position.z - station.position.z).length() > 2.5 or not station.is_available():
		return false
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
			if inventory.fuel < 1:
				notify("Генератору нужно топливо. Проверьте ящики на тропе.")
				return false
			inventory.fuel -= 1
			lighthouse_on = true
			beacon.set_powered(true)
			notify("Маяк зажжён. Теперь соберите древесину для укрепления.")
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
			if is_night() and lighthouse_on and barricade_built:
				hour = 5.85
				was_night = true
				notify("Вы укрылись в хижине. До рассвета осталось немного.")
			else:
				health = minf(100, health + 8)
				sanity = minf(100, sanity + 15)
				notify("Небольшая передышка. Ночью пригодятся маяк и укрепление.")
		"note":
			unlock_story("sign")
		"radio":
			unlock_story("radio")
			sound.radio_signal()
	if station.station_id != "radio":
		sound.interact(station.station_id)
	interaction_cooldown = 0.35
	return true

func start_fishing() -> void:
	fishing.begin()
	player.enabled = false
	player.velocity = Vector3.ZERO
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
	for at in [Vector3(-11, 1.5, 5), Vector3(0, 1.5, -10), Vector3(14, 1.5, 9)]:
		spawn_shadow(at)
	notify("На острове темнеет. Фонарь и свет маяка отгоняют тени.", 8)

func spawn_shadow(at: Vector3) -> void:
	var enemy := SHADOW_SCENE.instantiate()
	enemy.position = at
	enemy.keeper = player
	enemy.game = self
	add_child(enemy)
	enemies.append(enemy)

func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

func take_damage(amount: float) -> void:
	health = maxf(0, health - amount)
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
	refresh_journal()

func refresh_journal() -> void:
	if journal_entries.is_empty():
		hud.show_journal("Журнал смотрителя", "На острове слишком тихо.\n\nОсмотрите табличку на тропе к маяку и проверьте радиоприёмник у западной стены хижины. Здесь должны остаться следы тех, кто дежурил до вас.", "НАХОДКИ  /  0 ИЗ 2")
	else:
		journal_page = posmod(journal_page, journal_entries.size())
		var entry: Dictionary = STORIES[journal_entries[journal_page]]
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
	player.enabled = false
	hud.show_menu("win" if won else "loss")

func _input(event: InputEvent) -> void:
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
	if fishing.is_open():
		return
	if event is InputEventMouseButton and event.pressed and playing:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = maxf(18, target_zoom - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = minf(38, target_zoom + 2)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if journal_open:
		if event.physical_keycode in [KEY_ESCAPE, KEY_E, KEY_J]:
			close_journal()
		elif event.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
			turn_journal_page(-1 if event.physical_keycode == KEY_LEFT else 1)
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
		KEY_E:
			if interaction_cooldown <= 0:
				attempt_interaction(nearest_station)
		KEY_F:
			player.toggle_lantern()
		KEY_R:
			eat()
		KEY_Q:
			select_provision(true)
		KEY_T:
			select_provision(false)
		KEY_O:
			overview = not overview
		KEY_J:
			open_journal()
		KEY_V:
			coastal_life.cycle_weather()
			notify("Погода: " + ["автоматически", "дождь", "без дождя"][coastal_life.weather_mode])
		KEY_N:
			hour = 17.0 if is_night() else 22.0
			was_night = false
		KEY_F9:
			save_game()
		KEY_F10:
			load_game()

func save_game() -> bool:
	if not playing or finished or fishing.is_open():
		return false
	var state := {"version": 1, "inventory": inventory, "health": health, "hunger": hunger, "sanity": sanity, "hour": hour, "day": day, "fuel_found": fuel_found, "lighthouse_on": lighthouse_on, "barricade_built": barricade_built, "position": [player.position.x, player.position.y, player.position.z], "wood_remaining": 9, "was_night": was_night}
	state["journal"] = journal_entries
	state["weather_mode"] = coastal_life.weather_mode
	state["version"] = 2
	state["fish_items"] = fish_items
	state["food_items"] = food_items
	state["selected_fish"] = selected_fish
	state["selected_food"] = selected_food
	state["fishing_casts"] = fishing.casts
	for station in stations:
		if station.station_id == "wood":
			state.wood_remaining = station.remaining
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		notify("Не удалось сохранить смену.")
		return false
	file.store_string(JSON.stringify(state, "\t"))
	notify("Смена сохранена. F10 — загрузить.")
	hud.continue_button.show()
	return true

func load_game() -> bool:
	if fishing.is_open():
		return false
	if not FileAccess.file_exists(save_path):
		notify("Сохранения пока нет. F9 — сохранить смену.")
		return false
	var state = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not state is Dictionary or int(state.get("version", 0)) not in [1, 2]:
		notify("Файл сохранения не поддерживается.")
		return false
	playing = false
	start_shift()
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
	day = int(state.day)
	fuel_found = bool(state.fuel_found)
	lighthouse_on = bool(state.lighthouse_on)
	barricade_built = bool(state.barricade_built)
	was_night = bool(state.get("was_night", false))
	for entry in state.get("journal", []):
		if STORIES.has(entry):
			journal_entries.append(str(entry))
	coastal_life.weather_mode = int(state.get("weather_mode", 0))
	player.position = Vector3(state.position[0], state.position[1], state.position[2])
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
	return true

func capture_preview() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(capture_path)
	print("Captured preview: ", capture_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)
