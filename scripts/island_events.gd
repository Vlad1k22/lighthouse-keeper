extends Node3D
## Дневные происшествия: короткие задачи с таймером, которые ломают рутину обхода.
## Каждое событие необязательно, но даёт ресурсы, редкий улов или записки.
const Geo = preload("res://scripts/geometry.gd")
const PROVISIONS = preload("res://scripts/provisions.gd")
const GENERATOR := Vector3(-6.4, 1, -5.5)
const PIER := Vector3(23.3, .9, 5.0)
## Береговые точки, куда выбрасывает ящики и бутылки.
const SHORE := [
	Vector3(16,1,7.5), Vector3(-8,1,9.5), Vector3(-12.5,1,0), Vector3(14.5,1,-3),
	Vector3(12,1,-25), Vector3(-12,1,-30), Vector3(-21,1,-15), Vector3(3,1,-35),
	Vector3(9,1,10), Vector3(-15,1,-20)
]
const EVENTS := {
	"wreck": {"title":"ЯЩИК НА БЕРЕГУ","hint":"Заберите груз, пока его не смыло приливом","seconds":45.0,"day":2,"color":Color("f0a24a")},
	"bottle": {"title":"БУТЫЛКА В ПРИБОЕ","hint":"Кто-то бросил записку в море","seconds":40.0,"day":2,"color":Color("8fd7c0")},
	"shoal": {"title":"КОСЯК У ПРИЧАЛА","hint":"Редкая рыба клюёт только сейчас — бегите к причалу","seconds":50.0,"day":2,"color":Color("82b9df")},
	"sparks": {"title":"ГЕНЕРАТОР ИСКРИТ","hint":"Почините до перегрева, иначе сгорит запас топлива","seconds":32.0,"day":3,"color":Color("ff6a3d")},
	"fog": {"title":"ТУМАН С МОРЯ","hint":"В тумане бродит тень. Выжгите её лучом (ПКМ)","seconds":38.0,"day":4,"color":Color("9d84ff")}
}
const NOTES := [
	{"title":"Бутылка · Письмо без адреса","text":"«Если кто-то найдёт это — свет на Северном горел всю ночь. Мы видели его с палубы и повернули к берегу. Спасибо смотрителю». Даты нет. Бумага совсем свежая."},
	{"title":"Бутылка · Таблица приливов","text":"Таблица приливов на неделю вперёд. Напротив четырнадцатого дня обведено утро: «вода высокая, проход у буя открыт». Почерк ваш."},
	{"title":"Бутылка · Записка юнги","text":"«Тени не любят, когда на них смотрят. Фонарь держи прямо, не мигай. Они горят, как бумага». На обороте нарисован человек с фонарём."},
	{"title":"Бутылка · Последняя страница","text":"Обрывок вахтенного журнала: «Генератор глохнет, когда они подходят. Я поставил баррикаду, но они ломали её до утра. Если читаете — защищайте свет, а не себя»."},
	{"title":"Бутылка · Детский рисунок","text":"Рисунок цветными карандашами: маяк, лодка и четыре человечка на палубе. Подпись: «Папа возвращается домой». Бутылку принесло с юга."}
]

## Письма из выброшенных ящиков — пасхалки и кусочки истории острова.
const LETTERS := [
	{"title":"Письмо · «Дорогая Нина»","text":"«Нина, на маяке опять спорят, кто ночью поднимался к линзе. Я говорю — никто, а на ступенях мокрые следы. Если этот ящик доплывёт до тебя — не волнуйся. Свет горит. Целую. Твой Л.»"},
	{"title":"Письмо · Накладная склада","text":"Накладная №314. Отпущено на маяк «Северный»: керосин — 3 канистры, фонарь ручной — 1, фотоаппарат «Смена-8М» — 1 (вернуть после экспедиции!). Подпись кладовщика неразборчива."},
	{"title":"Письмо · Курсовая работа","text":"Обложка размокла, но читается: «Курсовой проект. Информационная система смотрителя маяка. Выполнил студент группы ИУК2-53Б». На полях красной ручкой: «Где диаграмма прецедентов?»"},
	{"title":"Письмо · Рецепт ухи","text":"«Уха по-северному: окунь, вода из колодца, щепоть соли, одна луковица. Главное — не уходить от печи: передержишь — горчит. Рыбу переворачивать, когда корочка золотая». Внизу приписка: «Проверено на трёх сменах»."},
	{"title":"Письмо · Записка без подписи","text":"«Не верь голосу, который знает твоё имя. Берег-четыре никогда не просит выйти к пляжу ночью. Он говорит только утром, по расписанию». Бумага пахнет керосином."},
	{"title":"Письмо · Открытка из Калуги","text":"На открытке — мост через Оку и надпись «Привет из Калуги!». На обороте: «Ребята, держитесь! Защита проекта в декабре. Вы справитесь. Ваш куратор»."},
	{"title":"Письмо · Схема огорода","text":"Карандашный план: три грядки у хижины, бочка с дождевой водой, стрелки «полить», «полить ещё раз». Внизу: «Вороны боятся резких движений и света. Не давай им сидеть дольше десяти секунд»."},
	{"title":"Письмо · Страница дневника","text":"«День 9. Сегодня впервые увидел их у баррикады. Они не ломают двери — они гасят свет. Обложил крыльцо камнем с каменоломни. Камень они не грызут, только скребут». Почерк похож на ваш."},
	{"title":"Письмо · Фотография","text":"Внутри — выцветший снимок: четверо на палубе «Северного», кто-то держит фонарь. На обороте: «Сфотографируйте свой остров. Потом будет что вспомнить»."},
	{"title":"Письмо · Телеграмма","text":"ТЕЛЕГРАММА. СЕВЕРНЫЙ СМОТРИТЕЛЮ ТЧК КАТЕР ЖДЁМ УТРОМ ЧЕТЫРНАДЦАТОГО ТЧК КОД ПРОВЕРЬТЕ ДВАЖДЫ ТЧК НЕ ГАСИТЕ СВЕТ ТЧК БЕРЕГ ЧЕТЫРЕ"}
]

var game: Node
var letters_found := 0
var rng := RandomNumberGenerator.new()
var current := ""
var time_left := 0.0
var duration := 1.0
var point := Vector3.ZERO
var clock := 0.0
var next_at := 12.0
var today := 0
var last_day := -1
var last_kind := ""
var marker: Node3D
var prop: Node3D
var fog_enemy: Node = null
var notes_found := 0
var results := {"done":0,"missed":0}

func _init() -> void:
	rng.randomize()

func reset() -> void:
	finish_quietly()
	letters_found = 0
	notes_found = 0
	clock = 0
	next_at = 12
	today = 0
	last_day = -1
	last_kind = ""
	results = {"done":0,"missed":0}

func is_active() -> bool:
	return not current.is_empty()

func eligible() -> bool:
	if not game.playing or game.finished or game.expedition.sailing or game.day < 1:
		return false
	if game.first_shift_demo.active():
		return false
	if game.campaign.enabled:
		if game.day == 1 and not game.campaign.goal_done(0):
			return false
		return not bool(game.campaign.state.night)
	return game.day >= 2 and not game.is_night() and game.hour < 18.5

func advance(delta: float) -> void:
	if last_day != game.day:
		last_day = game.day
		today = 0
		clock = 0
		next_at = 6.0 if game.day <= 2 else rng.randf_range(9, 14)
	if not eligible():
		if is_active():
			finish_quietly()
		return
	if not is_active():
		clock += delta
		var limit := 1 if game.day == 1 else (2 if game.day < 5 else 3)
		if clock >= next_at and today < limit:
			if today == 0 and game.day == 1:
				start("wreck")
			elif today == 0 and game.day == 2:
				start("fog")
			else:
				start_random()
		return
	time_left -= delta
	_animate_marker()
	if current == "fog" and (not is_instance_valid(fog_enemy) or fog_enemy.is_dissolving()):
		if is_instance_valid(fog_enemy):
			return
		succeed("Туман рассеялся вместе с тенью.", {"scrap":2})
		return
	if time_left <= 0:
		fail()

func options() -> Array:
	var list := []
	for kind in EVENTS:
		if game.day < int(EVENTS[kind].day) or kind == last_kind:
			continue
		if kind == "sparks" and not game.lighthouse_on and not (game.campaign.enabled and int(game.campaign.state.beacon_charge) > 0):
			continue
		if kind == "bottle" and notes_found >= NOTES.size():
			continue
		list.append(kind)
		if kind == "wreck" and letters_found < LETTERS.size():
			list.append(kind)
	return list

func start_random() -> void:
	var list := options()
	if list.is_empty():
		return
	start(list[rng.randi_range(0, list.size() - 1)])

func start(kind: String) -> bool:
	if not EVENTS.has(kind):
		return false
	finish_quietly()
	match kind:
		"wreck", "bottle":
			var spot: Variant = pick_shore()
			if spot == null:
				return false
			point = spot
			prop = build_crate(point) if kind == "wreck" else build_bottle(point)
		"shoal":
			point = PIER
		"sparks":
			point = GENERATOR
		"fog":
			var spot: Variant = fog_spawn()
			if spot == null:
				return false
			point = spot
			fog_enemy = game.spawn_shadow(point)
			fog_enemy.day_event = true
			fog_enemy.passive = false
			fog_enemy.max_darkness = 120
			fog_enemy.darkness = 120
	current = kind
	last_kind = kind
	today += 1
	clock = 0
	next_at = rng.randf_range(18, 26)
	duration = float(EVENTS[kind].seconds)
	time_left = duration
	marker = build_marker(point, EVENTS[kind].color)
	game.sound.cue("alarm")
	game.alert(EVENTS[kind].title, EVENTS[kind].hint, 4.5)
	game.radio.say("event_" + kind)
	return true

func pick_shore() -> Variant:
	var spots := []
	for spot in SHORE:
		var flat: float = Vector2(spot.x - game.player.position.x, spot.z - game.player.position.z).length()
		if flat < 7 or flat > 34:
			continue
		var ground: Variant = game.night_raids.ground_at(spot)
		if ground != null:
			spots.append(ground - Vector3(0, .35, 0))
	if spots.is_empty():
		return null
	return spots[rng.randi_range(0, spots.size() - 1)]

func fog_spawn() -> Variant:
	for attempt in 10:
		var angle := rng.randf() * TAU
		var spot: Variant = game.night_raids.ground_at(game.player.position + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(9, 12))
		if spot != null and not game.is_safe(spot):
			return spot
	return null

## Прямое взаимодействие с предметом события (ящик, бутылка) по E.
func interact() -> bool:
	if current not in ["wreck", "bottle"] or not is_instance_valid(prop):
		return false
	if Vector2(game.player.position.x - point.x, game.player.position.z - point.z).length() > 2.4:
		return false
	if current == "wreck":
		var loot: Dictionary = [{"scrap":2},{"fuel":1,"scrap":1},{"wood":3},{"food":1,"wood":1},{"scrap":3},{"stone":2,"wood":1}][rng.randi_range(0, 5)]
		var found := ""
		if letters_found < LETTERS.size() and (letters_found == 0 or rng.randf() < .85):
			var id := "letter:%d" % letters_found
			found = String(LETTERS[letters_found].title).trim_prefix("Письмо · ")
			letters_found += 1
			if id not in game.journal_entries:
				game.journal_entries.append(id)
		succeed(("Внутри письмо: «%s» (J). " % found if not found.is_empty() else "Ящик вскрыт до прилива. "), loot)
	else:
		var note: Dictionary = NOTES[notes_found % NOTES.size()]
		var id := "bottle:%d" % (notes_found % NOTES.size())
		notes_found += 1
		if id not in game.journal_entries:
			game.journal_entries.append(id)
		game.sanity = minf(100, game.sanity + 8)
		succeed("Записка в журнале (J): «%s»." % String(note.title).trim_prefix("Бутылка · "), {})
	game.player.play_gesture("interact")
	return true

func prompt() -> String:
	if current in ["wreck", "bottle"] and Vector2(game.player.position.x - point.x, game.player.position.z - point.z).length() <= 2.4:
		return "[E] " + ("Вскрыть ящик" if current == "wreck" else "Достать записку из бутылки")
	return ""

## Генератор во время события «искры». 1 — починено, -1 — не наше.
func intercept(id: String) -> int:
	if current == "sparks" and id == "beacon":
		game.sound.interact("beacon")
		succeed("Проводка заменена, генератор работает ровно.", {"sanity":6})
		return 1
	return -1

func species_bonus() -> String:
	if current != "shoal":
		return ""
	var roll := rng.randf()
	return "sturgeon" if roll < .28 else ("mackerel" if roll < .85 else "perch")

func on_fish_caught() -> void:
	if current == "shoal":
		succeed("Косяк ушёл, но лучшая рыба уже в садке.", {})

func journal_entry(id: String) -> Dictionary:
	if id.begins_with("letter:"):
		var letter := int(id.trim_prefix("letter:"))
		return LETTERS[letter] if letter >= 0 and letter < LETTERS.size() else {}
	if not id.begins_with("bottle:"):
		return {}
	var index := int(id.trim_prefix("bottle:"))
	return NOTES[index] if index >= 0 and index < NOTES.size() else {}

func grant(reward: Dictionary) -> String:
	var parts := []
	for key in reward:
		var amount := int(reward[key])
		match key:
			"scrap":
				game.expedition.state.scrap = int(game.expedition.state.scrap) + amount
				parts.append("+%d дет." % amount)
			"fuel":
				game.inventory.fuel += amount
				parts.append("+%d топл." % amount)
			"wood":
				game.inventory.wood += amount
				parts.append("+%d дерева" % amount)
			"food":
				for i in amount:
					game.food_items.append(PROVISIONS.ration())
				game.sync_provisions()
				parts.append("+%d паёк" % amount)
			"sanity":
				game.sanity = minf(100, game.sanity + amount)
				parts.append("+%d рассудка" % amount)
			"stone":
				game.inventory.stone = int(game.inventory.get("stone", 0)) + amount
				parts.append("+%d камня" % amount)
	return " ".join(parts)

func succeed(text: String, reward: Dictionary) -> void:
	var title: String = EVENTS[current].title
	var gained := grant(reward)
	results.done += 1
	game.feedback(point, gained if not gained.is_empty() else "Готово")
	game.sound.cue("chime")
	game.alert("✓ " + title, text + ("  " + gained if not gained.is_empty() else ""), 4)
	finish_quietly()

func fail() -> void:
	var title: String = EVENTS[current].title
	results.missed += 1
	var text := "Время вышло."
	match current:
		"wreck": text = "Прилив унёс ящик в море."
		"bottle": text = "Бутылку утянуло обратно в волны."
		"shoal": text = "Косяк ушёл на глубину."
		"fog": text = "Туман отступил, тень растворилась сама."
		"sparks":
			text = "Генератор перегрелся."
			if game.campaign.enabled and int(game.campaign.state.beacon_charge) > 0:
				game.campaign.state.beacon_charge = int(game.campaign.state.beacon_charge) - 1
				text += " Запас топлива −1 ночь."
			elif game.inventory.fuel > 0:
				game.inventory.fuel -= 1
				text += " Сгорела канистра топлива."
	game.alert("✗ " + title, text, 4)
	finish_quietly()

func finish_quietly() -> void:
	if current == "fog" and is_instance_valid(fog_enemy) and not fog_enemy.is_dissolving():
		fog_enemy.dissolve()
	fog_enemy = null
	current = ""
	time_left = 0
	for node in [marker, prop]:
		if is_instance_valid(node):
			node.queue_free()
	marker = null
	prop = null

func keeps_day_enemies() -> bool:
	return current == "fog"

func fog_strength() -> float:
	return clampf(time_left / 4.0, 0, 1) if current == "fog" else 0.0

func banner() -> Dictionary:
	if not is_active():
		return {}
	var distance := Vector2(game.player.position.x - point.x, game.player.position.z - point.z).length()
	return {"title":EVENTS[current].title,"hint":EVENTS[current].hint,"time":time_left,"ratio":time_left / duration,"distance":distance,"color":EVENTS[current].color}

func map_point() -> Variant:
	return point if is_active() else null

func _glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	return material

func build_marker(at: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "EventMarker"
	add_child(root)
	root.global_position = at
	var pillar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .05
	mesh.bottom_radius = .45
	mesh.height = 16
	mesh.cap_top = false
	mesh.cap_bottom = false
	pillar.mesh = mesh
	pillar.position.y = 8
	pillar.material_override = _glow_material(color, .22)
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pillar)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.25
	ring.mesh = torus
	ring.position.y = .08
	ring.material_override = _glow_material(color, .7)
	root.add_child(ring)
	var icon := Label3D.new()
	icon.name = "Icon"
	icon.text = "!"
	icon.font_size = 96
	icon.pixel_size = .012
	icon.outline_size = 18
	icon.modulate = color
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.position.y = 3.4
	root.add_child(icon)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 4.5
	light.position.y = 1.2
	root.add_child(light)
	return root

func _animate_marker() -> void:
	if not is_instance_valid(marker):
		return
	var t := Time.get_ticks_msec() * .001
	marker.get_node("Ring").scale = Vector3.ONE * (1.0 + sin(t * 4.0) * .08)
	var icon: Label3D = marker.get_node("Icon")
	icon.position.y = 3.4 + sin(t * 3.0) * .18
	var urgent := time_left < 10.0
	icon.modulate.a = (.45 + .55 * absf(sin(t * 9.0))) if urgent else 1.0
	if current == "sparks" and rng.randf() < .2:
		game.camera_shake = maxf(game.camera_shake, .05)

func build_crate(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "WreckCrate"
	add_child(root)
	root.global_position = at
	var body := Geo.box(root, "Crate", Vector3(0, .38, 0), Vector3(.95, .7, .7), Color("8a6a43"))
	body.rotation.y = .4
	for x in [-.36, .36]:
		var strap := Geo.box(root, "Strap", Vector3(x * cos(.4), .38, -x * sin(.4)), Vector3(.08, .74, .74), Color("4d3b27"))
		strap.rotation.y = .4
	var lid := Geo.box(root, "Tarp", Vector3(.05, .76, .02), Vector3(.8, .06, .55), Color("3d5a5f"))
	lid.rotation = Vector3(.08, .5, .06)
	return root

func build_bottle(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "DriftBottle"
	add_child(root)
	root.global_position = at
	var glass := Geo.cylinder(root, "Bottle", Vector3(0, .14, 0), .11, .42, Color("4f8a6e"))
	glass.rotation = Vector3(0, .3, 1.35)
	Geo.cylinder(root, "Cork", Vector3(.25, .16, 0), .05, .09, Color("a07a4f")).rotation.z = 1.35
	return root
