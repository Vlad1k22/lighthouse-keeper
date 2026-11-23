extends Node
## Ночная оборона: волны теней идут гасить маяк и ломать баррикаду хижины.
## Отсидеться в свете больше нельзя — смотритель сам решает, что защищать.
const GENERATOR := Vector3(-6.4, 1, -5.5)
const BARRICADE_FRONT := Vector3(4.8, 1, 6.5)
const GENERATOR_SABOTAGE := 2.6
const BARRICADE_DPS := 7.5
const MAX_ALIVE := 6
## Точки выхода теней по краю острова. Перед появлением проверяется земля.
const EDGE_POINTS := [
	Vector3(14,1.5,9), Vector3(-13,1.5,4), Vector3(0,1.5,-10), Vector3(12,1.3,-6),
	Vector3(-2,1.3,12), Vector3(16,1.3,1), Vector3(-14,1.3,-12), Vector3(8,1.3,12),
	Vector3(-9,1.3,11), Vector3(-1,1.3,-15)
]
## Насколько сильна осада в ночь каждого типа.
const PRESSURE := {"knocks":.8,"watcher":.7,"static":.9,"storm":1.2,"echo":1.0,"double":.9,"blackout":1.0,"silence":.7,"siege":1.6,"false_call":1.1,"last":1.5,"free":1.0}

var game: Node
var rng := RandomNumberGenerator.new()
var active := false
var clock := 0.0
var next_wave := 0.0
var wave := 0
var dispelled := 0
var light_lost := false
var barricade_hp := 100.0
var barricade_broken := false
var barricade_hit := false
var sabotaged := false
var warned_barricade := false
var report := ""
var raid_night := false

func _init() -> void:
	rng.randomize()

func reset() -> void:
	active = false
	clock = 0
	next_wave = 0
	wave = 0
	dispelled = 0
	light_lost = false
	barricade_hp = 100
	barricade_broken = false
	barricade_hit = false
	sabotaged = false
	warned_barricade = false
	report = ""
	raid_night = false

func night_kind() -> String:
	if game.campaign.enabled:
		return String(game.campaign.entry().night.kind)
	return "free"

func night_length() -> float:
	if game.campaign.enabled:
		return float(game.campaign.entry().night.seconds)
	return 60.0

func eligible() -> bool:
	if not game.playing or game.finished or game.expedition.sailing or game.day < 2:
		return false
	if game.first_shift_demo.active():
		return false
	if game.campaign.enabled:
		return bool(game.campaign.state.night) and game.day < game.campaign.calendar_days()
	return game.is_night()

func night_clock() -> float:
	return float(game.campaign.state.night_clock) if game.campaign.enabled else clock

func advance(delta: float) -> void:
	if not eligible():
		if active:
			active = false
		return
	if not active:
		active = true
		raid_night = true
		clock = 0
		next_wave = 5.5
		wave = 0
		dispelled = 0
		light_lost = false
		barricade_hit = false
		warned_barricade = false
		if not barricade_broken:
			barricade_hp = max_hp()
	clock += delta
	if sabotaged and game.lighthouse_on:
		sabotaged = false
	if clock >= next_wave and night_clock() < night_length() - 4:
		spawn_wave()
		var interval := clampf(10.5 - game.day * .35, 6.0, 10.0) / sqrt(PRESSURE.get(night_kind(), 1.0))
		next_wave = clock + interval
	if game.sanity < 38 and rng.randf() < delta * .09 and count_alive() < MAX_ALIVE:
		spawn_phantom()

func count_alive() -> int:
	var alive := 0
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.is_dissolving():
			alive += 1
	return alive

func ground_at(point: Vector3) -> Variant:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 14, point.z), Vector3(point.x, -4, point.z))
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty() or hit.position.y < .3 or hit.position.y > 3.2 or hit.normal.y < .7:
		return null
	return hit.position + Vector3(0, .35, 0)

func pick_spawn(near: Vector3) -> Variant:
	var options := []
	for point in EDGE_POINTS:
		var flat: float = Vector2(point.x - game.player.position.x, point.z - game.player.position.z).length()
		if flat < 8.5:
			continue
		var ground: Variant = ground_at(point)
		if ground == null:
			continue
		options.append([Vector2(point.x - near.x, point.z - near.z).length() + rng.randf_range(0, 6), ground])
	if options.is_empty():
		return null
	options.sort_custom(func(a, b): return a[0] < b[0])
	return options[rng.randi_range(0, mini(2, options.size() - 1))][1]

func targets() -> Array:
	var list := []
	if game.lighthouse_on:
		list.append("generator")
	if game.barricade_built:
		list.append("barricade")
	list.append("")
	return list

func spawn_wave() -> void:
	wave += 1
	var pressure: float = PRESSURE.get(night_kind(), 1.0)
	var base := 1 if game.day < 5 else (2 if game.day < 10 else 3)
	var count := clampi(roundi(base * pressure), 1, 4)
	count = mini(count, MAX_ALIVE - count_alive())
	var goals := targets()
	var names := []
	for i in count:
		var goal: String = goals[(wave + i) % goals.size()]
		var destination: Vector3 = GENERATOR if goal == "generator" else (BARRICADE_FRONT if goal == "barricade" else game.player.position)
		var point: Variant = pick_spawn(destination)
		if point == null:
			continue
		var kind := "drowned" if i == 0 and wave % 3 == 0 and game.day >= 6 else "shadow"
		var enemy: CharacterBody3D = game.spawn_shadow(point, kind)
		enemy.goal = goal
		enemy.goal_point = destination
		enemy.passive = false
		enemy.max_darkness = 100.0 + game.day * 6.0 + (60.0 if kind == "drowned" else 0.0)
		enemy.darkness = enemy.max_darkness
		if not names.has(goal):
			names.append(goal)
	if names.is_empty():
		return
	game.sound.horror_cue("whisper", game.player.position + Vector3(0, 0, -6))
	var text := []
	for goal in names:
		text.append({"generator":"к генератору","barricade":"к баррикаде","":"к вам"}[goal])
	game.alert("ВОЛНА %d · тени идут %s" % [wave, ", ".join(text)], "ПКМ — луч фонаря выжигает тьму" if wave == 1 else "Защитите свет до рассвета", 4.5)
	if wave == 1:
		game.radio.say("raid_first", true)
	if wave == 1 and game.day <= 3:
		game.notify("Тени тянутся к свету, чтобы погасить его. Зажмите ПКМ (или C) — луч фонаря выжигает их.", 8)

func spawn_phantom() -> void:
	var angle := rng.randf() * TAU
	var point: Variant = ground_at(game.player.position + Vector3(cos(angle), 0, sin(angle)) * 6.5)
	if point == null:
		return
	var enemy: CharacterBody3D = game.spawn_shadow(point)
	enemy.passive = true
	enemy.phantom = true
	enemy.max_darkness = 35
	enemy.darkness = 35
	game.sound.horror_cue("whisper", point)

## Вызывается тенью, которая добралась до цели.
func on_sabotage(enemy: Node, delta: float) -> void:
	match String(enemy.goal):
		"generator":
			if not game.lighthouse_on:
				retarget(enemy)
				return
			game.camera_shake = maxf(game.camera_shake, .25)
			if enemy.sabotage >= GENERATOR_SABOTAGE:
				cut_power()
				retarget(enemy)
		"barricade":
			if not game.barricade_built:
				retarget(enemy)
				return
			var armor: float = game.homestead.armor() if is_instance_valid(game.homestead) else 0.0
			barricade_hp = maxf(0, barricade_hp - BARRICADE_DPS * delta * (1.0 - armor))
			barricade_hit = true
			if barricade_hp < max_hp() * .55 and not warned_barricade:
				warned_barricade = true
				game.alert("БАРРИКАДУ ЛОМАЮТ · %d%%" % roundi(barricade_hp / max_hp() * 100.0), "Бегите к хижине и выжгите тени лучом", 4)
				game.sound.cue("alarm")
			if barricade_hp <= 0:
				break_barricade()
				retarget(enemy)

func retarget(enemy: Node) -> void:
	enemy.goal = ""
	enemy.sabotage = 0

func cut_power() -> void:
	if not game.lighthouse_on:
		return
	game.lighthouse_on = false
	game.beacon.set_powered(false)
	sabotaged = true
	light_lost = true
	game.camera_shake = 1.2
	game.sound.cue("alarm")
	game.alert("МАЯК ПОГАС!", "Тень сорвала генератор. Перезапустите его — E у генератора", 6)
	game.notify("Тени погасили маяк. Без луча остров беззащитен — бегите к генератору.", 7)
	game.radio.say("light_out", false, true)

func break_barricade() -> void:
	game.barricade_built = false
	barricade_broken = true
	if is_instance_valid(game.barricade):
		game.feedback(game.barricade.global_position, "БАРРИКАДА СЛОМАНА")
		game.barricade.queue_free()
		game.barricade = null
	game.camera_shake = 1.2
	game.sound.cue("alarm")
	game.alert("БАРРИКАДА СЛОМАНА", "Хижина больше не защищает. Верстак: 1 дерево на ремонт", 6)
	game.radio.say("barricade_broken", false, true)

## Действия у станций, которые меняются после ночной вылазки. 1 — выполнено, 0 — отказ, -1 — не наше.
func intercept(id: String) -> int:
	if id == "beacon" and sabotaged and not (game.campaign.enabled and game.campaign.state.blackout):
		sabotaged = false
		game.lighthouse_on = true
		game.beacon.set_powered(true)
		game.sound.interact("beacon")
		game.feedback(GENERATOR, "Маяк снова горит")
		game.alert("СВЕТ ВОССТАНОВЛЕН", "Луч маяка снова обжигает тени", 3.5)
		game.sound.cue("chime")
		return 1
	if id == "workbench" and barricade_broken and not game.barricade_built:
		if game.inventory.wood < 1:
			game.notify("Для ремонта баррикады нужно 1 дерево. Валежник — к западу от хижины.")
			return 0
		game.inventory.wood -= 1
		game.barricade_built = true
		game.build_barricade()
		barricade_broken = false
		barricade_hp = max_hp()
		game.sound.interact("wood")
		game.feedback(game.barricade.global_position, "Баррикада восстановлена · −1 дерево")
		game.sound.cue("chime")
		return 1
	return -1

func on_dispelled(enemy: Node) -> void:
	if active:
		dispelled += 1

## Утро после ночи: подводим итог обороны и выдаём награду за смелость.
func on_dawn() -> void:
	active = false
	sabotaged = false
	if not raid_night:
		report = ""
		return
	raid_night = false
	var parts := []
	var scrap := mini(4, dispelled / 2)
	if scrap > 0:
		game.expedition.state.scrap = int(game.expedition.state.scrap) + scrap
		parts.append("рассеяно теней: %d → +%d дет." % [dispelled, scrap])
	elif dispelled > 0:
		parts.append("рассеяно теней: %d" % dispelled)
	var held := not light_lost and not barricade_broken and not barricade_hit
	if held and wave > 0:
		game.inventory.fuel += 1
		game.sanity = minf(100, game.sanity + 10)
		parts.append("свет и хижина невредимы → +1 топливо")
		game.radio.say("dawn_good")
	if not barricade_broken:
		barricade_hp = max_hp()
	report = ("Итог ночи: " + ", ".join(parts) + ".") if not parts.is_empty() else ""
	game.night_report = report

func status_text() -> String:
	if not active:
		return ""
	var light := "горит" if game.lighthouse_on else "ПОГАС"
	var shelter := ("%d%%" % roundi(barricade_hp / max_hp() * 100.0)) if game.barricade_built else "СЛОМАНА"
	return "\n\nОБОРОНА · волна %d\nМаяк: %s · Баррикада: %s\nРассеяно теней: %d" % [wave, light, shelter, dispelled]

## Прочность баррикады растёт с каждым участком укреплений вокруг хижины.
func max_hp() -> float:
	return 100.0 + (game.homestead.bonus_hp() if is_instance_valid(game.homestead) else 0.0)

func save_data() -> Dictionary:
	return {"barricade_hp": barricade_hp, "barricade_broken": barricade_broken, "sabotaged": sabotaged}

func restore(data: Dictionary) -> void:
	reset()
	barricade_hp = maxf(0, float(data.get("barricade_hp", 100.0)))
	barricade_broken = bool(data.get("barricade_broken", false))
	sabotaged = bool(data.get("sabotaged", false))
