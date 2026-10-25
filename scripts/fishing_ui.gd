extends Control
## Собственный интерфейс мини-игры в морской палитре проекта.
const INK := Color("102b32")
const PAPER := Color("e9e3ce")
const GOLD := Color("deb777")
const MUTED := Color("97b1ac")
const GREEN := Color("8bbd96")
const RED := Color("cf8c75")
const PROVISIONS = preload("res://scripts/provisions.gd")
var game: Node
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func box(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func words(at: Vector2, value: String, size_px: int = 20, color: Color = PAPER) -> void:
	var y := at.y
	for line in value.split("\n"):
		draw_string(font, Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
		y += size_px * 1.45

func fish_icon(at: Vector2, scale_factor: float = 1.0, color: Color = GOLD) -> void:
	var points := PackedVector2Array([Vector2(-22, 0), Vector2(-10, -12), Vector2(9, -11), Vector2(22, 0), Vector2(9, 11), Vector2(-10, 12)])
	for index in points.size():
		points[index] = at + points[index] * scale_factor
	draw_colored_polygon(points, color)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-18, 0) * scale_factor, at + Vector2(-32, -13) * scale_factor, at + Vector2(-32, 13) * scale_factor]), color)
	draw_circle(at + Vector2(11, -3) * scale_factor, 2.3 * scale_factor, INK)

func _draw() -> void:
	if not is_instance_valid(game) or not game.fishing.is_open():
		return
	var f = game.fishing
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.05, 0.065, 0.63))
	var scale_factor := minf(size.x / 1440.0, size.y / 900.0)
	draw_set_transform((size - Vector2(1440, 900) * scale_factor) * 0.5, 0, Vector2.ONE * scale_factor)
	var origin := Vector2(430, 110)
	box(Rect2(origin + Vector2(0, 8), Vector2(580, 680)), Color(0, 0, 0, 0.25), Color.TRANSPARENT, 18)
	box(Rect2(origin, Vector2(580, 680)), INK, Color("7a8670"), 18)
	words(origin + Vector2(32, 39), "СЕВЕРНЫЙ БЕРЕГ   /   РЫБАЛКА", 13, GOLD)
	var title := "Тихая вода"
	if f.phase == f.Phase.BITE:
		title = "Клюёт!"
	elif f.phase == f.Phase.REELING:
		title = str(f.fish.name)
	elif f.phase == f.Phase.RESULT:
		title = "Хороший улов" if f.caught else "Рыба ушла"
	words(origin + Vector2(32, 83), title, 32)
	var subtitle := "Причал смотрителя  ·  морская рыба"
	if f.phase == f.Phase.REELING or (f.phase == f.Phase.RESULT and f.caught):
		subtitle = PROVISIONS.rarity_name(f.fish) + " рыба"
	words(origin + Vector2(32, 113), subtitle, 16, PROVISIONS.rarity_color(f.fish) if subtitle != "Причал смотрителя  ·  морская рыба" else MUTED)
	draw_line(origin + Vector2(32, 133), origin + Vector2(548, 133), Color("345154"), 1)
	if f.phase == f.Phase.REELING:
		draw_reeling(origin)
	else:
		draw_cast(origin)
	draw_line(origin + Vector2(32, 564), origin + Vector2(548, 564), Color("345154"), 1)
	var action := "Дождитесь поклёвки"
	if f.phase == f.Phase.BITE:
		action = "ПРОБЕЛ / ЛКМ — подсечь"
	elif f.phase == f.Phase.REELING:
		action = "Держать — вверх  ·  отпустить — вниз"
	elif f.phase == f.Phase.RESULT:
		action = "ПРОБЕЛ / ЛКМ — вернуться"
	words(origin + Vector2(32, 601), action, 21, GOLD)
	words(origin + Vector2(32, 635), "Esc — выйти из рыбалки", 16, MUTED)
	words(origin + Vector2(32, 660), "Время острова приостановлено", 13, MUTED)

func draw_reeling(origin: Vector2) -> void:
	var f = game.fishing
	var lane := Rect2(origin + Vector2(56, 170), Vector2(92, 352))
	box(lane.grow(5), Color("203e46"), Color("56767a"), 10)
	box(lane, Color("17323b"), Color.TRANSPARENT, 7)
	for index in 8:
		var y := lane.position.y + (index + 0.5) * 44
		draw_line(Vector2(lane.position.x + 8, y), Vector2(lane.end.x - 8, y), Color("2a4d57"), 1)
	var zone := Rect2(Vector2(lane.position.x + 5, lane.position.y + (1.0 - f.bar_position - f.bar_size * 0.5) * lane.size.y), Vector2(82, f.bar_size * lane.size.y))
	box(zone, Color(0.37, 0.64, 0.43, 0.65) if f.in_zone else Color(0.39, 0.48, 0.4, 0.7), GREEN, 5)
	fish_icon(Vector2(lane.get_center().x, lane.position.y + (1.0 - f.fish_position) * lane.size.y), 0.95, PAPER)
	var meter := Rect2(origin + Vector2(169, 170), Vector2(16, 352))
	box(meter, Color("294349"), Color.TRANSPARENT, 4)
	box(Rect2(Vector2(meter.position.x, meter.end.y - f.progress * meter.size.y), Vector2(16, f.progress * meter.size.y)), GREEN if f.in_zone else GOLD, Color.TRANSPARENT, 4)
	words(origin + Vector2(55, 158), "ГЛУБИНА", 12, MUTED)
	words(origin + Vector2(224, 191), "Удерживайте рыбу\nв зелёной зоне", 25)
	words(origin + Vector2(224, 280), "Улов растёт, пока рыба\nнаходится внутри полоски.\nВне зоны рыба срывается.", 18, MUTED)
	box(Rect2(origin + Vector2(224, 375), Vector2(306, 52)), Color("254a47") if f.in_zone else Color("493c35"), Color.TRANSPARENT, 8)
	words(origin + Vector2(242, 408), "РЫБА В ЗОНЕ" if f.in_zone else "ЛЕСКА ОСЛАБЛА", 18, GREEN if f.in_zone else RED)
	words(origin + Vector2(224, 472), "Улов  %d%%" % roundi(f.progress * 100), 25, GOLD)
	words(origin + Vector2(224, 509), "Пробел или левая кнопка мыши", 16, MUTED)

func draw_cast(origin: Vector2) -> void:
	var f = game.fishing
	var center := origin + Vector2(129, 332)
	box(Rect2(origin + Vector2(36, 170), Vector2(186, 352)), Color("173942"), Color.TRANSPARENT, 12)
	for index in 5:
		var y := origin.y + 202 + index * 68
		draw_line(Vector2(origin.x + 53, y), Vector2(origin.x + 205, y), Color("315760"), 1)
	if f.phase == f.Phase.RESULT:
		fish_icon(center, 2.1, PROVISIONS.rarity_color(f.fish) if f.caught else MUTED)
		words(origin + Vector2(254, 201), str(f.fish.name) if f.caught else "Попробуем ещё?", 24)
		if f.caught:
			words(origin + Vector2(254, 244), PROVISIONS.rarity_name(f.fish).to_upper(), 16, PROVISIONS.rarity_color(f.fish))
			words(origin + Vector2(254, 280), "+1 РЫБА   ·   %d г" % f.weight, 22, GREEN)
			var meal := PROVISIONS.fish_item(str(f.fish.id), f.weight)
			var benefit := PROVISIONS.bonuses(meal)
			words(origin + Vector2(254, 321), "После готовки и еды:\n+%d здоровья · +%d сытости" % [benefit.health, benefit.hunger], 17, PAPER)
			if f.perfect:
				words(origin + Vector2(254, 390), "ИДЕАЛЬНЫЙ УЛОВ", 14, GOLD)
		words(origin + Vector2(254, 434 if f.caught else 340), f.result_text, 18, MUTED)
	else:
		var bob := sin(f.phase_time * (12 if f.phase == f.Phase.BITE else 2.4)) * (8 if f.phase == f.Phase.BITE else 3)
		var at := center + Vector2(0, bob)
		draw_line(origin + Vector2(130, 180), at, Color("9fb9b3"), 1.5)
		draw_arc(at + Vector2(0, 15), 35 + sin(f.phase_time * 3) * 5, 0, TAU, 48, Color("628e91"), 1.5, true)
		draw_circle(at, 11, GOLD)
		draw_circle(at + Vector2(0, -5), 6, PAPER)
		if f.phase == f.Phase.BITE:
			words(origin + Vector2(113, 265), "!", 50, GOLD)
			words(origin + Vector2(254, 207), "Рыба на крючке!", 24, GOLD)
			words(origin + Vector2(254, 267), "Нажмите Пробел\nили левую кнопку мыши,\nчтобы подсечь.", 19)
			var remaining := maxf(0, 1 - f.phase_time / 3.0)
			box(Rect2(origin + Vector2(254, 388), Vector2(270, 8)), Color("294349"), Color.TRANSPARENT, 4)
			box(Rect2(origin + Vector2(254, 388), Vector2(270 * remaining, 8)), GOLD, Color.TRANSPARENT, 4)
			words(origin + Vector2(254, 438), "Не упустите поклёвку", 16, MUTED)
		else:
			words(origin + Vector2(254, 207), "Поплавок на воде", 24)
			words(origin + Vector2(254, 267), "Скоро начнётся поклёвка.\nПодсеките, когда появится\nнадпись «Клюёт!».", 19, MUTED)
			words(origin + Vector2(254, 414), "Обычная, редкая, легендарная.\nЧем реже и тяжелее рыба,\nтем сытнее получится ужин.", 16, MUTED)
