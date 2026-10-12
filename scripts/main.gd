extends Node3D
## Контроллер первой смены: задания, время суток, выживание, сохранение.
const HUD = preload("res://scripts/hud.gd")
const SOUND = preload("res://scripts/soundscape.gd")
const SHADOW_SCENE = preload("res://scenes/shadow.tscn")
const Geo = preload("res://scripts/geometry.gd")

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
var busy_time := 0.0
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

func _ready() -> void:
	beacon = world.find_child("Lighthouse", true, false)
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
	if "--preview-day" in OS.get_cmdline_user_args():
		start_shift()
		overview = true
		hour = 16.8
		fuel_found = true
		lighthouse_on = true
		beacon.set_powered(true)
		notify("Маяк снова горит. Подготовьте убежище к ночи.")
	elif "--preview-night" in OS.get_cmdline_user_args():
		start_shift()
		overview = true
		hour = 22
		fuel_found = true
		lighthouse_on = true
		barricade_built = true
		build_barricade()
		beacon.set_powered(true)
	elif "--preview-play" in OS.get_cmdline_user_args():
		start_shift()
		hour = 18.3
		lighthouse_on = true
		fuel_found = true
		beacon.set_powered(true)
		notify("Маяк снова горит. Подготовьте убежище к ночи.")
	if not capture_path.is_empty():
		if "--preview-play" in OS.get_cmdline_user_args():
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
		player.enabled = true
		hud.show_game()
		return
	inventory = {"fuel": 0, "wood": 0, "fish": 0, "food": 1}
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
	was_night = false
	night_spawned = false
	busy_time = 0
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
	var active := playing and not paused and not finished
	if active:
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
		if busy_time > 0:
			busy_time -= delta
			if busy_time <= 0:
				inventory.fish += 1
				player.enabled = true
				notify("Есть улов! Приготовьте рыбу на печи возле хижины.")
				sound.interact()
		update_nearest()
		if player.position.y < -2:
			player.position = Vector3(3, 1.3, 4)
			player.velocity = Vector3.ZERO
			take_damage(10)
			notify("Течение слишком сильное. Вы вернулись к хижине.")
	message_time = maxf(0, message_time - delta)
	update_atmosphere()
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

func update_atmosphere() -> void:
	var night := 0.0
	if hour >= 17:
		night = smoothstep(17.0, 21.0, hour)
	elif hour < 7:
		night = 1.0 - smoothstep(5.0, 7.0, hour)
	var env: Environment = world.get_node("CoastalAtmosphere").environment
	env.ambient_light_energy = lerpf(0.48, 0.30, night)
	env.ambient_light_color = Color("adbcba").lerp(Color("638392"), night)
	env.fog_light_color = Color("819b9c").lerp(Color("1a3949"), night)
	env.fog_density = lerpf(0.0025, 0.006, night)
	env.background_color = Color("315d68").lerp(Color("122c3c"), night)
	var sun: DirectionalLight3D = world.get_node("Sun")
	sun.light_energy = lerpf(1.0, 0.3, night)
	sun.light_color = Color("f6dec0").lerp(Color("8dbad2"), night)
	world.get_node("Ocean").material_override.set_shader_parameter("night_factor", night)

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
		return "Соберите 3 дерева в лесу. Затем идите к верстаку."
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

func attempt_interaction(station: Area3D) -> bool:
	if not playing or paused or finished or busy_time > 0 or not is_instance_valid(station):
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
		"wood":
			inventory.wood += 1
			station.consume()
			notify("Древесина +1. Для укрепления нужно 3.")
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
		"fish":
			busy_time = 3.0
			player.enabled = false
			notify("Забрасываем удочку…")
		"cook":
			if inventory.fish < 1:
				notify("Сначала поймайте рыбу на причале.")
				return false
			inventory.fish -= 1
			inventory.food += 1
			notify("Ужин готов. Нажмите R, чтобы поесть.")
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
			notify("«Если услышишь шаги за собой — не гаси свет».\nПочерк подозрительно похож на ваш.", 9)
	sound.interact()
	interaction_cooldown = 0.35
	return true

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
	notify("Тень рядом! Включите фонарь или бегите к свету.")

func eat() -> bool:
	if inventory.food < 1:
		notify("В рюкзаке нет еды. Причал и печь помогут приготовить ужин.")
		return false
	inventory.food -= 1
	hunger = minf(100, hunger + 35)
	health = minf(100, health + 5)
	notify("Вы поели. Сытость восстановлена.")
	sound.interact()
	return true

func notify(content: String, duration: float = 5.0) -> void:
	message = content
	message_time = duration

func finish_shift(won: bool) -> void:
	finished = true
	player.enabled = false
	hud.show_menu("win" if won else "loss")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and playing:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = maxf(18, target_zoom - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = minf(38, target_zoom + 2)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE and playing and not finished:
		paused = not paused
		player.enabled = not paused and busy_time <= 0
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
		KEY_O:
			overview = not overview
		KEY_N:
			hour = 17.0 if is_night() else 22.0
			was_night = false
		KEY_F9:
			save_game()
		KEY_F10:
			load_game()

func save_game() -> bool:
	if not playing or finished:
		return false
	var state := {"version": 1, "inventory": inventory, "health": health, "hunger": hunger, "sanity": sanity, "hour": hour, "day": day, "fuel_found": fuel_found, "lighthouse_on": lighthouse_on, "barricade_built": barricade_built, "position": [player.position.x, player.position.y, player.position.z], "wood_remaining": 9, "was_night": was_night}
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
	if not FileAccess.file_exists(save_path):
		notify("Сохранения пока нет. F9 — сохранить смену.")
		return false
	var state = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not state is Dictionary or state.get("version", 0) != 1:
		notify("Файл сохранения не поддерживается.")
		return false
	playing = false
	start_shift()
	for key in inventory.keys():
		inventory[key] = int(state.inventory.get(key, 0))
	health = float(state.health)
	hunger = float(state.hunger)
	sanity = float(state.sanity)
	hour = float(state.hour)
	day = int(state.day)
	fuel_found = bool(state.fuel_found)
	lighthouse_on = bool(state.lighthouse_on)
	barricade_built = bool(state.barricade_built)
	was_night = bool(state.get("was_night", false))
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
