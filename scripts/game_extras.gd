extends RefCounted
## Предметы интерьеров и пасхалки: граммофон и плакат в хижине, метеодоска радиостанции,
## портрет капитана и журнал экипажа в рубке катера, табличка у фермы.
const Geo = preload("res://scripts/geometry.gd")
const GRAMOPHONE = preload("res://assets/models/interiors/gramophone.glb")
const RECORD = preload("res://assets/audio/music/gramophone.wav")
const POSTER_TEX = preload("res://assets/easter/shutter_poster.png")
const CAPTAIN_TEX = preload("res://assets/easter/captain_painting.png")
const HAYDAY_TEX = preload("res://assets/easter/hayday_sign.png")
## Чёткие версии для крупного осмотра.
const CLOSEUP := {
	"poster": ["res://assets/easter/shutter_poster_full.png", "ПЛАКАТ «ОСТРОВ ПРОКЛЯТЫХ»", "Тоже остров, тоже маяк. Прежний смотритель обвёл маяк красным: «не верь маяку!» На обороте: «Тедди, это всего лишь смена. Свет — настоящий. Ты — тоже»."],
	"captain": ["res://assets/easter/captain_painting_full.png", "ПОРТРЕТ КАПИТАНА", "Экипаж «Северного» начинал с этой картиной каждую вахту. Капитан ждёт ответа: «Да, капитан!»"],
	"hayday": ["res://assets/easter/hayday_sign.png", "ТАБЛИЧКА У ГРЯДОК", "Снизу нацарапано: «Заказ для грузовика: 3 моркови, 2 репы. Срок — до шторма. Монет не будет». Прежний смотритель явно скучал по большой земле."],
}
const GRAMOPHONE_AT := Vector3(-2.43,0,1.51)
const CREW_LOG_AT := Vector3(1.52,.68,1.93)
## Точка у таблички фермы (снаружи, рядом с грядками).
const SIGN_AT := Vector3(15.1, 1, 2.75)
## Где стоять, чтобы взаимодействовать: комната → [id, локальная точка, радиус].
const SPOTS := {
	"cabin": [["gramophone", GRAMOPHONE_AT, .91], ["poster", Vector3(-2.05, 0, .55), .75]],
	"radio": [["forecast", Vector3(-1.75, 0, .62), .8]],
	"ship": [["crew_log", CREW_LOG_AT, .91], ["captain", Vector3(-1.62, 0, -1.05), .8]],
}
const KINDS := {
	"knocks":"стук в двери", "watcher":"наблюдатель у кромки леса", "static":"помехи в эфире",
	"storm":"шторм", "echo":"эхо шагов", "double":"двойник", "blackout":"обрыв питания",
	"silence":"мёртвый штиль", "siege":"осада", "false_call":"ложный вызов", "last":"последняя ночь", "free":"спокойная ночь",
}
const STORIES := {
	"poster": {"title":"Плакат «Остров проклятых»", "text":"Старый плакат: тоже остров, тоже маяк. Прежний смотритель обвёл маяк красным и подписал: «не верь маяку!»\n\nНа обороте карандашом: «Тедди, это всего лишь смена. Свет — настоящий. Ты — тоже».\n\nХорошо, что наш остров другой. Правда ведь?"},
	"captain": {"title":"Портрет капитана", "text":"Бородатый капитан в треуголке, повязка на глазу, попугай на плече. Табличку на раме стёрла соль.\n\nСудя по зарубкам на косяке, экипаж «Северного» начинал с этой картиной каждую вахту. Если громко ответить «Да, капитан!», почему-то становится легче.\n\nКаждый день: +10 к рассудку."},
	"forecast": {"title":"Метеодоска радиостанции", "text":"Мелом выведены даты, стрелки ветра и пометки на полях — прежний радист каждое утро записывал, чего ждать ночью.\n\nПоследняя строчка: «Сводку читать каждый день. Знать, что идёт, — уже половина обороны».\n\nПрочитанная сводка: +8 к рассудку, этой ночью фонарь заряжается быстрее."},
	"hayday": {"title":"Табличка у грядок", "text":"«HAY DAY · Ферма смотрителя». Петух на табличке улыбается так, будто знает про вас всё.\n\nСнизу нацарапано: «Заказ для грузовика: 3 моркови, 2 репы. Срок — до шторма. Монет не будет».\n\nКажется, прежний смотритель очень скучал по большой земле."},
}
var game: Node
var record_player: AudioStreamPlayer3D
var forecast_board: Label3D
var forecast_day := -1
var captain_day := -1
var captain_calls := 0
var visited: Array[String] = []

func setup_outdoor(world: Node3D) -> void:
	var sign := Node3D.new()
	sign.name = "HayDaySign"
	world.add_child(sign)
	sign.global_position = SIGN_AT
	sign.rotation.y = atan2(6.1, 8.8)
	for x in [-.72, .72]:
		Geo.box(sign, "Post", Vector3(x, .62, -.14), Vector3(.12, 1.24, .12), Color("5b4029"), true)
	Geo.box(sign, "Back", Vector3(0, 1.12, -.07), Vector3(1.86, .98, .06), Color("4a3220"))
	_picture(sign, HAYDAY_TEX, Vector3(0, 1.12, -.035), Vector2(1.78, .89), 0.0)

func _picture(parent: Node3D, texture: Texture2D, at: Vector3, size: Vector2, yaw: float, glow := 0.0) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = .85
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if glow > 0:
		material.emission_enabled = true
		material.emission_texture = texture
		material.emission_energy_multiplier = glow
	var mesh := MeshInstance3D.new()
	mesh.name = "Picture"
	mesh.mesh = quad
	mesh.material_override = material
	mesh.position = at
	mesh.rotation.y = yaw
	parent.add_child(mesh)
	return mesh

## Вызывается при каждом входе в комнату: ставит реквизит один раз, обновляет доску.
func install_room(id: String, room: Node3D) -> void:
	if id not in visited and id in ["radio","ship"]:
		visited.append(id)
		if game.playing:
			game.alert("РАДИОСТАНЦИЯ" if id == "radio" else "РУБКА «СЕВЕРНОГО»", "На западной стене — метеодоска: сводка на ночь (+рассудок)." if id == "radio" else "На стене — портрет капитана. Поприветствуйте его (+рассудок).", 4.5)
	match id:
		"cabin":
			install_cabin(room)
			if not room.has_node("Poster"):
				var poster := Node3D.new()
				poster.name = "Poster"
				room.add_child(poster)
				_picture(poster, POSTER_TEX, Vector3(-2.995, 1.48, .55), Vector2(.74, 1.13), PI*.5, .12)
		"radio":
			if not room.has_node("ForecastBoard"):
				var board := Node3D.new()
				board.name = "ForecastBoard"
				room.add_child(board)
				board.position = Vector3(-2.39, 1.5, .62)
				board.rotation.y = PI*.5
				Geo.box(board, "Frame", Vector3(0, 0, -.015), Vector3(1.18, .82, .03), Color("6a4a2c"))
				Geo.box(board, "Slate", Vector3(0, 0, .002), Vector3(1.08, .72, .01), Color("1f2a26"))
				forecast_board = Label3D.new()
				forecast_board.name = "Chalk"
				forecast_board.font_size = 40
				forecast_board.pixel_size = .0022
				forecast_board.width = 440
				forecast_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				forecast_board.modulate = Color("e9efe4")
				forecast_board.outline_size = 0
				forecast_board.position.z = .012
				board.add_child(forecast_board)
			refresh_board()
		"ship":
			if not room.has_node("CaptainPortrait"):
				var frame := Node3D.new()
				frame.name = "CaptainPortrait"
				room.add_child(frame)
				Geo.box(frame, "Backing", Vector3(-2.265, 1.47, -1.05), Vector3(.03, .6, .7), Color("3b2a18"))
				_picture(frame, CAPTAIN_TEX, Vector3(-2.245, 1.47, -1.05), Vector2(.66, .56), PI*.5, .1)

func install_cabin(room: Node3D) -> void:
	if room.has_node("Gramophone"):
		return
	var prop := GRAMOPHONE.instantiate() as Node3D
	prop.name = "Gramophone"
	prop.position = GRAMOPHONE_AT
	room.add_child(prop)
	var body := StaticBody3D.new()
	prop.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.61,.78,.52)
	collision.shape = shape
	collision.position.y = .39
	body.add_child(collision)
	record_player = AudioStreamPlayer3D.new()
	record_player.stream = game.sound.repeat_track(RECORD)
	record_player.bus = "Music"
	record_player.volume_db = -10
	record_player.unit_size = 1.9
	record_player.max_distance = 6.8
	record_player.position.y = 1.06
	prop.add_child(record_player)

func stop_record() -> void:
	if is_instance_valid(record_player):
		record_player.stop()

func forecast() -> Dictionary:
	var campaign: RefCounted = game.campaign
	if not campaign.enabled:
		return {"kind":"free", "seconds":0, "threat":"неизвестна"}
	var night: Dictionary = campaign.entry().night
	var kind := String(night.kind)
	var pressure: float = game.NIGHT_RAIDS.PRESSURE.get(kind, 1.0)
	var threat := "низкая" if pressure <= .8 else "средняя" if pressure <= 1.0 else "высокая" if pressure <= 1.2 else "критическая"
	return {"kind":kind, "seconds":int(night.seconds), "threat":threat}

func forecast_text() -> String:
	var info := forecast()
	var lines := "СВОДКА · ДЕНЬ %02d\n\nНочью: %s\nУгроза: %s" % [game.day, KINDS.get(info.kind, "неизвестно"), info.threat]
	if int(info.seconds) > 0:
		lines += "\nДержаться: %d сек" % int(info.seconds)
	return lines

func refresh_board() -> void:
	if is_instance_valid(forecast_board):
		forecast_board.text = forecast_text()

func nearby() -> String:
	var id: String = game.building_interiors.active
	if id.is_empty():
		if game.lighthouse_interior.active or not game.playing:
			return ""
		var at: Vector3 = game.player.global_position
		return "hayday" if Vector2(at.x-SIGN_AT.x, at.z-SIGN_AT.z).length() < 1.35 and absf(at.y-SIGN_AT.y) < 1.2 else ""
	if not SPOTS.has(id) or not game.building_interiors.instances.has(id):
		return ""
	var room := game.building_interiors.instances[id] as Node3D
	var local: Vector3 = room.to_local(game.player.global_position)
	var best := ""
	var best_distance := INF
	for spot in SPOTS[id]:
		var offset: Vector3 = local - spot[1]
		var distance := Vector2(offset.x, offset.z).length()
		if distance < float(spot[2]) and distance < best_distance:
			best = spot[0]
			best_distance = distance
	return best

func prompt() -> String:
	match nearby():
		"gramophone":
			return "[E] Остановить пластинку" if is_instance_valid(record_player) and record_player.playing else "[E] Завести граммофон"
		"crew_log":
			return "[E] Листок под койкой"
		"poster":
			return "[E] Осмотреть плакат"
		"forecast":
			return "[E] Прочитать метеосводку на ночь"
		"captain":
			return "[E] Осмотреть картину · отдать честь капитану"
		"hayday":
			return "[E] Осмотреть табличку фермы"
	return ""

func interact() -> bool:
	match nearby():
		"gramophone":
			if not is_instance_valid(record_player):
				return false
			if record_player.playing:
				stop_record()
			else:
				record_player.play()
			game.interaction_cooldown = .28
			return true
		"crew_log":
			game.unlock_story("crew_log")
			return true
		"poster":
			if game.is_night():
				game.sanity = maxf(0, game.sanity - 4)
			inspect("poster")
			return true
		"forecast":
			read_forecast()
			return true
		"captain":
			salute_captain()
			inspect("captain")
			return true
		"hayday":
			inspect("hayday")
			return true
	return false

## Открыть крупное изображение; находка тихо попадает в журнал (J).
func inspect(id: String) -> void:
	var info: Array = CLOSEUP[id]
	if id not in game.journal_entries:
		game.journal_entries.append(id)
		game.alert("НАХОДКА", "Пасхалка добавлена в журнал · J", 3.0)
	if is_instance_valid(game.viewer) and game.viewer.has_method("open"):
		game.viewer.open(load(info[0]), info[1], info[2])
	game.interaction_cooldown = .4

func _story_once(id: String) -> void:
	if id not in game.journal_entries:
		game.unlock_story(id)

func read_forecast() -> void:
	refresh_board()
	var info := forecast()
	var first: bool = forecast_day != game.day
	if first:
		forecast_day = game.day
		game.sanity = minf(100, game.sanity + 8)
	_story_once("forecast")
	var text := "Ночью: %s · угроза %s" % [KINDS.get(info.kind, "неизвестно"), info.threat]
	if int(info.seconds) > 0:
		text += " · %d сек" % int(info.seconds)
	game.alert("МЕТЕОСВОДКА", text + ("  ·  +8 рассудок, фонарь заряжается быстрее" if first else ""), 5.0)
	game.sound.interact("paper")
	game.interaction_cooldown = .4

func forecast_bonus() -> float:
	return 1.3 if forecast_day == game.day else 1.0

func salute_captain() -> void:
	var first_today: bool = captain_day != game.day
	if first_today:
		captain_day = game.day
		captain_calls = 0
		game.sanity = minf(100, game.sanity + 10)
	captain_calls += 1
	if captain_calls % 2 == 1:
		game.radio.say("captain_ready", false, true)
		game.alert("КАПИТАН НА КАРТИНЕ", "«Да, капитан!»" + ("  ·  +10 рассудок" if first_today else ""), 3.6)
	else:
		game.radio.say("captain_louder", false, true)
		game.alert("КАПИТАН НА КАРТИНЕ", "«ТАК ТОЧНО, КАПИТАН!!!»", 3.2)
	game.camera_shake = maxf(game.camera_shake, .08)
	game.interaction_cooldown = .5

func save_data() -> Dictionary:
	return {"forecast_day":forecast_day, "captain_day":captain_day}

func restore(data: Dictionary) -> void:
	forecast_day = int(data.get("forecast_day", -1))
	captain_day = int(data.get("captain_day", -1))
	captain_calls = 0
