extends Control
## Слой «режиссуры» поверх HUD: куда идти, что случилось и что только что получилось.
## Маркер текущей цели в мире, стрелка у края экрана, баннеры событий и заставки дня/ночи.
const TEAL := Color("8fd7c0")
const GOLD := Color("deb777")
const PAPER := Color("e9e3ce")
const INK := Color(0.03, 0.09, 0.11, 0.88)

var game: Node
var marker: Node3D
var marker_label: Label3D
var target_point := Vector3.ZERO
var target_name := ""
var has_target := false
var alert_title := ""
var alert_text := ""
var alert_time := 0.0
var alert_total := 1.0
var alert_color := GOLD
var card_title := ""
var card_text := ""
var card_time := 0.0
var last_phase := ""
var last_done := -1
var last_day := -1
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font

func alert(title: String, text: String, seconds: float = 4.0, color: Color = GOLD) -> void:
	alert_title = title
	alert_text = text
	alert_time = seconds
	alert_total = seconds
	alert_color = color

func title_card(title: String, text: String) -> void:
	card_title = title
	card_text = text
	card_time = 4.2

func _ensure_marker() -> void:
	if is_instance_valid(marker):
		return
	marker = Node3D.new()
	marker.name = "ObjectiveMarker"
	game.add_child(marker)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(TEAL.r, TEAL.g, TEAL.b, .15)
	var pillar := MeshInstance3D.new()
	pillar.name = "Pillar"
	var mesh := CylinderMesh.new()
	mesh.top_radius = .04
	mesh.bottom_radius = .32
	mesh.height = 12
	mesh.cap_top = false
	mesh.cap_bottom = false
	pillar.mesh = mesh
	pillar.position.y = 6
	pillar.material_override = material
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(pillar)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = .85
	torus.outer_radius = 1.0
	ring.mesh = torus
	ring.position.y = .06
	var ring_material := material.duplicate()
	ring_material.albedo_color.a = .6
	ring.material_override = ring_material
	marker.add_child(ring)
	marker_label = Label3D.new()
	marker_label.name = "Label"
	marker_label.font_size = 40
	marker_label.pixel_size = .0085
	marker_label.outline_size = 12
	marker_label.outline_modulate = Color(0.02, 0.07, 0.08, .9)
	marker_label.modulate = TEAL
	marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_label.no_depth_test = true
	marker_label.position.y = 3.0
	marker.add_child(marker_label)

func current_target() -> void:
	has_target = false
	if not game.playing or game.finished or not game.campaign.enabled or game.expedition.sailing:
		return
	if game.lighthouse_interior.active or not game.building_interiors.active.is_empty():
		return
	var id: String = game.campaign.target_id()
	if id.is_empty():
		return
	if id == "lighthouse_lens":
		target_point = game.LIGHTHOUSE_INTERIOR.OUTSIDE_DOOR
		target_name = "Подняться к линзе маяка"
		has_target = true
		return
	if game.INTERIOR_STATIONS.has(id):
		var room: String = game.INTERIOR_STATIONS[id]
		target_point = game.building_interiors.exit_at(room)
		target_name = "Войти в радиостанцию" if room == "radio" else "Войти в рубку катера"
		has_target = true
		return
	for station in game.stations:
		if station.station_id == id and station.visible:
			target_point = station.global_position
			target_name = game.campaign.prompt(id, station.display_name)
			has_target = true
			return

func watch_progress() -> void:
	if not game.playing or game.finished or not game.campaign.enabled:
		last_phase = ""
		return
	var night: bool = game.campaign.state.night
	var phase := "%d:%s" % [game.day, "night" if night else "day"]
	if phase != last_phase:
		var first := last_phase.is_empty()
		last_phase = phase
		var record: Dictionary = game.campaign.entry()
		if game.first_shift_demo.active():
			pass
		elif night:
			title_card("НОЧЬ %02d" % game.day, "Продержитесь до рассвета · защищайте свет" if game.day >= 2 else String(record.title))
			if game.day >= 2:
				game.radio.say("night_start")
		elif not first or game.day > 1:
			title_card("ДЕНЬ %02d · %s" % [game.day, String(record.title).to_upper()], String(record.brief))
		elif first:
			title_card("ДЕНЬ 01 · %s" % String(record.title).to_upper(), String(record.brief))
		if not night and not game.first_shift_demo.active():
			game.radio.say("brief_%d" % game.day, true)
		last_done = -1
	if night:
		return
	var done := 0
	var total: int = game.campaign.entry().goals.size()
	for i in total:
		if game.campaign.goal_done(i):
			done += 1
	if last_done >= 0 and done > last_done:
		game.sound.cue("chime")
		if done >= total:
			alert("✓ ВСЕ ДЕЛА ДНЯ СДЕЛАНЫ", "Включите фонарь (F) и идите в хижину — встречать ночь", 5, TEAL)
		else:
			alert("✓ ЦЕЛЬ ВЫПОЛНЕНА  %d / %d" % [done, total], "Дальше: " + String(game.campaign.entry().goals[game.campaign.next_index()].title), 4, TEAL)
	last_done = done

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	alert_time = maxf(0, alert_time - delta)
	card_time = maxf(0, card_time - delta)
	watch_progress()
	current_target()
	_ensure_marker()
	marker.visible = has_target and game.hud.game_ui.visible
	if marker.visible:
		var ground: Vector3 = target_point
		ground.y = maxf(.9, target_point.y) - .95
		marker.global_position = ground
		var t := Time.get_ticks_msec() * .001
		marker.get_node("Ring").scale = Vector3.ONE * (1.0 + sin(t * 3.0) * .07)
		var distance := Vector2(game.player.position.x - target_point.x, game.player.position.z - target_point.z).length()
		marker_label.text = "◆ %d м" % roundi(distance) if distance > 3 else "◆"
		marker_label.position.y = 3.0 + sin(t * 2.4) * .12
		marker.get_node("Pillar").visible = distance > 4
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game) or not game.hud.game_ui.visible:
		return
	_draw_objective()
	_draw_dawn_bar()
	_draw_radio()
	_draw_arrow()
	_draw_event_banner()
	_draw_alert()
	_draw_card()
	_draw_lantern_hint()

func _text(content: String, at: Vector2, size_px: int, color: Color, width: float = -1, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, at + Vector2(2, 2), content, align, width, size_px, Color(0, 0, 0, color.a * .6))
	draw_string(font, at, content, align, width, size_px, color)

func _draw_arrow() -> void:
	if not has_target or game.paused:
		return
	var camera: Camera3D = game.camera
	var view := get_viewport_rect().size
	var screen := camera.unproject_position(target_point + Vector3(0, 1, 0))
	var margin := 70.0
	var inside := Rect2(Vector2(margin, margin + 60), view - Vector2(margin * 2, margin * 2 + 160)).has_point(screen)
	var distance := Vector2(game.player.position.x - target_point.x, game.player.position.z - target_point.z).length()
	if inside:
		return
	var center := view * .5
	var direction := (screen - center).normalized()
	if direction == Vector2.ZERO:
		return
	# Стрелка держится внутри игрового поля, не заходя на панели журнала, карты и рюкзака.
	var limit := Vector2(view.x * .5 - 360, view.y * .5 - 150)
	var scale_x := limit.x / maxf(.001, absf(direction.x))
	var scale_y := limit.y / maxf(.001, absf(direction.y))
	var tip := center + direction * minf(scale_x, scale_y)
	var pulse := .75 + .25 * sin(Time.get_ticks_msec() * .006)
	var side := direction.orthogonal()
	var arrow := PackedVector2Array([tip + direction * 20, tip - direction * 8 + side * 15, tip - direction * 2, tip - direction * 8 - side * 15])
	draw_colored_polygon(arrow, Color(TEAL.r, TEAL.g, TEAL.b, pulse))
	var label := "%s · %d м" % [target_name, roundi(distance)]
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var at := tip - direction * 48 - Vector2(width * .5, -5)
	at.x = clampf(at.x, 348, view.x - width - 200)
	at.y = clampf(at.y, 20, view.y - 20)
	draw_rect(Rect2(at + Vector2(-8, -18), Vector2(width + 16, 26)), INK)
	_text(label, at, 15, TEAL)

## Одно конкретное действие «прямо сейчас» — главный ответ на вопрос «что мне делать?».
func objective() -> Dictionary:
	if not game.playing or game.finished or not game.campaign.enabled or game.first_shift_demo.active():
		return {}
	var campaign: RefCounted = game.campaign
	var state: Dictionary = campaign.state
	var in_cabin: bool = game.building_interiors.active == "cabin"
	var inside: bool = not game.building_interiors.active.is_empty() or game.lighthouse_interior.active
	var text := ""
	if game.expedition.sailing:
		return {"text":"Курс на материк — держитесь маршрута к внешнему бую"}
	if state.night:
		var left: int = maxi(0, ceili(float(campaign.entry().night.seconds) - float(state.night_clock)))
		var finished_night: bool = bool(state.event_done) and left <= 0
		if game.day == 1:
			if finished_night:
				text = "Встретить рассвет: E у койки" if in_cabin else "Войдите в хижину (E у двери) и нажмите E у койки"
			else:
				text = campaign.night_instruction()
		elif not state.event_done:
			text = campaign.night_instruction().trim_suffix(" · E.").trim_suffix(".")
		elif not finished_night:
			var missing_now: String = campaign.prep_missing()
			text = missing_now if not missing_now.is_empty() else "Защищайте генератор и хижину — выжигайте тени лучом (ПКМ)"
		else:
			var missing: String = campaign.prep_missing()
			text = ("Рассвет ждёт: " + missing) if not missing.is_empty() else "Рассвет наступает…"
		return {"text":text,"night":true}
	var index: int = campaign.next_index()
	if index >= 0:
		var goal: Dictionary = campaign.entry().goals[index]
		text = String(goal.title)
		if goal.id == "lighthouse_lens":
			text = "Войдите в маяк (E у двери) и поднимитесь к линзе" if not game.lighthouse_interior.active else "Поднимитесь по лестнице к линзе и нажмите E"
		elif game.INTERIOR_STATIONS.has(goal.id):
			var room: String = game.INTERIOR_STATIONS[goal.id]
			if game.building_interiors.active == room:
				text += " · E у %s (◆)" % ("передатчика" if room == "radio" else "штурвала")
			else:
				text += " · внутри %s" % ("радиостанции" if room == "radio" else "рубки катера")
		elif inside and not in_cabin and not game.lighthouse_interior.active:
			text += " · выйдите наружу (◇)"
	elif game.day >= campaign.calendar_days():
		text = "Встаньте к штурвалу и нажмите E" if game.building_interiors.active == "ship" else "Войдите в рубку катера и встаньте к штурвалу"
	else:
		var missing: String = campaign.prep_missing()
		if not missing.is_empty():
			text = missing
		elif game.day == 1:
			text = "Начать ночь: E у койки в хижине" if in_cabin else "Войдите в хижину (E у двери), затем E у койки"
		else:
			text = "Всё готово. Встретить ночь: E у хижины"
	return {"text":text}

func _draw_objective() -> void:
	var data := objective()
	if data.is_empty() or String(data.text).is_empty():
		return
	var view := get_viewport_rect().size
	var label := String(data.text)
	if has_target and not game.lighthouse_interior.active and game.building_interiors.active.is_empty():
		label += "  ·  %d м" % roundi(Vector2(game.player.position.x - target_point.x, game.player.position.z - target_point.z).length())
	var width := 520.0
	var lines := _wrap(label, width - 92, 17)
	var box := Rect2(view.x * .5 - width * .5, 20, width, 26 + lines.size() * 22)
	var accent: Color = Color("ff9a6a") if data.get("night", false) else TEAL
	draw_rect(box, INK)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 3)), accent)
	_text("ЦЕЛЬ", box.position + Vector2(16, 29), 12, GOLD)
	for i in lines.size():
		_text(lines[i], box.position + Vector2(70, 30 + i * 22), 17, PAPER)

## Ночной таймер обороны: сколько держаться, какая волна и что под угрозой.
func _draw_dawn_bar() -> void:
	if not game.campaign.enabled or not game.campaign.state.night or game.day < 2 or game.first_shift_demo.active():
		return
	var total: float = float(game.campaign.entry().night.seconds)
	var clock: float = float(game.campaign.state.night_clock)
	var left := maxf(0, total - clock)
	var view := get_viewport_rect().size
	var box := Rect2(view.x * .5 - 260, _dawn_bar_top(), 520, 72)
	draw_rect(box, INK)
	var ratio := clampf(clock / maxf(1, total), 0, 1)
	draw_rect(Rect2(box.position + Vector2(16, 36), Vector2(box.size.x - 32, 7)), Color(1, 1, 1, .1))
	draw_rect(Rect2(box.position + Vector2(16, 36), Vector2((box.size.x - 32) * ratio, 7)), Color("ffcf7a"))
	var title := "ДО РАССВЕТА  %d:%02d" % [int(left) / 60, int(left) % 60] if left > 0 else "РАССВЕТ БЛИЗКО"
	_text(title, box.position + Vector2(16, 27), 18, Color("ffcf7a"))
	var raids: Node = game.night_raids
	var info := "Волна %d" % raids.wave
	var next: float = raids.next_wave - raids.clock
	if left > 4 and next > 0:
		info += " · следующая через %d с" % ceili(next)
	info += "   Маяк %s · Хижина %s" % ["✓" if game.lighthouse_on else "✗", ("%d%%" % roundi(raids.barricade_hp / raids.max_hp() * 100.0)) if game.barricade_built else "✗"]
	draw_string(font, box.position + Vector2(16, 62), info, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32, 13, PAPER)

func _dawn_bar_top() -> float:
	return 20.0 + 26 + _wrap(_objective_label(), 520 - 92, 17).size() * 22 + 8

func _objective_label() -> String:
	var data := objective()
	if data.is_empty():
		return ""
	var label := String(data.text)
	if has_target and not game.lighthouse_interior.active and game.building_interiors.active.is_empty():
		label += "  ·  %d м" % roundi(Vector2(game.player.position.x - target_point.x, game.player.position.z - target_point.z).length())
	return label

func _draw_radio() -> void:
	var data: Dictionary = game.radio.subtitle()
	if data.is_empty():
		return
	var view := get_viewport_rect().size
	var width := 600.0
	var lines := _wrap(String(data.text), width - 40, 18)
	var hint := String(data.hint)
	var height := 46.0 + lines.size() * 25.0 + (24.0 if not hint.is_empty() else 0.0)
	var box := Rect2(view.x * .5 - width * .5, 718 - height, width, height)
	var color: Color = Color("b89cff") if data.style == "ghost" else (Color("c9b78f") if data.style == "record" else TEAL)
	draw_rect(box, Color(0.02, 0.06, 0.08, .9))
	draw_rect(Rect2(box.position, Vector2(4, box.size.y)), color)
	var pulse := .55 + .45 * absf(sin(Time.get_ticks_msec() * .012))
	draw_circle(box.position + Vector2(22, 20), 5, Color(color.r, color.g, color.b, pulse))
	_text("РАДИО · " + String(data.speaker), box.position + Vector2(36, 26), 13, color)
	for i in lines.size():
		_text(lines[i], box.position + Vector2(20, 52 + i * 25), 18, PAPER)
	if not hint.is_empty():
		_text(hint, box.position + Vector2(20, 52 + lines.size() * 25), 14, GOLD)

func _wrap(content: String, width: float, size_px: int) -> PackedStringArray:
	var result := PackedStringArray()
	var line := ""
	for word in content.split(" "):
		var trial := word if line.is_empty() else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width and not line.is_empty():
			result.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		result.append(line)
	return result

func _draw_event_banner() -> void:
	var data: Dictionary = game.island_events.banner()
	if data.is_empty():
		var shot: Dictionary = game.photo.banner()
		if shot.is_empty():
			return
		data = {"title":shot.title,"hint":String(shot.hint) + " · P — фотоаппарат","time":shot.time,"ratio":shot.ratio,"distance":0.0,"color":Color("f0d48a")}
	var view := get_viewport_rect().size
	var box := Rect2(view.x * .5 - 280, 96, 560, 74)
	var color: Color = data.color
	draw_rect(box, INK)
	draw_rect(Rect2(box.position, Vector2(4, box.size.y)), color)
	var urgent: bool = data.time < 10
	var blink := (.55 + .45 * absf(sin(Time.get_ticks_msec() * .008))) if urgent else 1.0
	_text((String(data.title) if String(data.title).begins_with("◉") else "⚠ " + String(data.title)), box.position + Vector2(18, 26), 19, Color(color.r, color.g, color.b, blink))
	var timer := "%d:%02d" % [int(data.time) / 60, int(data.time) % 60]
	_text(timer, box.position + Vector2(box.size.x - 80, 26), 19, Color("ff8a6a") if urgent else PAPER)
	_text(("%s · %d м" % [data.hint, roundi(data.distance)]) if float(data.distance) > 0 else String(data.hint), box.position + Vector2(18, 50), 13, PAPER)
	draw_rect(Rect2(box.position + Vector2(18, 60), Vector2((box.size.x - 36), 4)), Color(1, 1, 1, .1))
	draw_rect(Rect2(box.position + Vector2(18, 60), Vector2((box.size.x - 36) * float(data.ratio), 4)), color)

func _draw_alert() -> void:
	if alert_time <= 0 or alert_title.is_empty():
		return
	var view := get_viewport_rect().size
	var fade := minf(1.0, alert_time / .4) * minf(1.0, (alert_total - alert_time) / .2 + .2)
	var y := 182.0 if game.island_events.is_active() or not game.photo.banner().is_empty() else 98.0
	if game.campaign.enabled and game.campaign.state.night and game.day >= 2:
		y = _dawn_bar_top() + 82.0
	var title_width := font.get_string_size(alert_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var text_width := font.get_string_size(alert_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var width := maxf(title_width, text_width) + 60
	var box := Rect2(view.x * .5 - width * .5, y, width, 72)
	draw_rect(box, Color(INK.r, INK.g, INK.b, INK.a * fade))
	draw_rect(Rect2(box.position + Vector2(0, box.size.y - 3), Vector2(box.size.x, 3)), Color(alert_color.r, alert_color.g, alert_color.b, fade))
	_text(alert_title, Vector2(view.x * .5 - title_width * .5, y + 32), 26, Color(alert_color.r, alert_color.g, alert_color.b, fade))
	_text(alert_text, Vector2(view.x * .5 - text_width * .5, y + 56), 15, Color(PAPER.r, PAPER.g, PAPER.b, fade))

func _draw_card() -> void:
	if card_time <= 0:
		return
	var view := get_viewport_rect().size
	var fade := minf(1.0, card_time / .8) * minf(1.0, (4.2 - card_time) / .5)
	var band := Rect2(0, view.y * .5 - 82, view.x, 150)
	draw_rect(band, Color(0.02, 0.06, 0.08, .72 * fade))
	draw_line(Vector2(view.x * .5 - 220, band.position.y + 30), Vector2(view.x * .5 + 220, band.position.y + 30), Color(GOLD.r, GOLD.g, GOLD.b, .5 * fade), 1)
	var title_width := font.get_string_size(card_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	_text(card_title, Vector2(view.x * .5 - title_width * .5, band.position.y + 82), 44, Color(PAPER.r, PAPER.g, PAPER.b, fade))
	var shown := card_text if card_text.length() < 110 else card_text.substr(0, 107) + "…"
	var text_width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	_text(shown, Vector2(view.x * .5 - text_width * .5, band.position.y + 116), 17, Color(GOLD.r, GOLD.g, GOLD.b, fade))

func _draw_lantern_hint() -> void:
	if not game.lantern_beam.focusing:
		return
	var screen: Vector2 = game.camera.unproject_position(game.player.global_position + Vector3(0, 2.6, 0))
	var ratio: float = game.lantern_beam.charge / 100.0
	draw_rect(Rect2(screen + Vector2(-34, 0), Vector2(68, 6)), Color(0, 0, 0, .6))
	draw_rect(Rect2(screen + Vector2(-33, 1), Vector2(66 * ratio, 4)), Color("ffcf7a") if ratio > .3 else Color("ff7a5a"))
