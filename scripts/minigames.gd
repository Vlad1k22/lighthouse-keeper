extends Control
## Короткие мини-игры вместо одиночного нажатия E: ремонт механизмов, жарка рыбы и розжиг костра.
## Открываются только из прямого действия игрока (клавиша E) и только когда действие выполнимо.
## Пробел или ЛКМ — главное действие, Esc — отмена без потери ресурсов.
enum Mode { NONE, REPAIR, COOK, FIRE }
const INK := Color(0.02, 0.06, 0.08, 0.94)
const PAPER := Color("e9e3ce")
const GOLD := Color("deb777")
const TEAL := Color("8fd7c0")
const RED := Color("ff7a5a")
const REPAIRS := {
	"beacon": {"title":"Запуск генератора","hint":"Ловите стрелку в зелёном секторе — пробел или ЛКМ. Три точных импульса заведут генератор."},
	"sparks": {"title":"Проводка генератора","hint":"Замкните три контакта, пока проводка не перегорела."},
	"transmitter": {"title":"Ремонт передатчика","hint":"Подстройте три контура: жмите, когда стрелка в зелёном секторе."},
	"pump": {"title":"Насос колодца","hint":"Затяните три фланца точными рывками ключа."},
	"ship_engine": {"title":"Двигатель катера","hint":"Выставьте зажигание: три точных импульса."},
	"ship_hull": {"title":"Пробоина корпуса","hint":"Забейте три гвоздя — бейте, когда стрелка в зелёном секторе."},
	"quarry": {"title":"Каменоломня","hint":"Бейте киркой по трещине в зелёном секторе. Без промахов — лишний камень."}
}

var game: Node
## В автотестах (headless) нажатие E выполняет действие сразу; мини-игры проверяются отдельным тестом.
var enabled := DisplayServer.get_name() != "headless"
var mode := Mode.NONE
var station: Area3D
var kind := ""
var on_done: Callable
var font: Font
var clock := 0.0
var result_text := ""
var result_time := 0.0
var success := false
# Ремонт
var needle := 0.0
var needle_speed := 2.2
var sector := 0.0
var sector_width := 0.6
var hits := 0
var misses := 0
var perfect := false
var flash := 0.0
var sparks: Array = []
# Жарка
var side := 0
var doneness := 0.0
var sides_good := 0
var burnt := false
var cook_result := ""
# Костёр
var stage := 0
var striker := 0.0
var embers := 0
var flame := 0.0
var steady := 0.0
var blowing := false

func setup(owner_game: Node) -> void:
	game = owner_game
	font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func is_open() -> bool:
	return visible

## Решает, нужно ли действие у станции проводить через мини-игру. Возвращает true, если игра открыта.
func offer(target: Area3D) -> bool:
	if not enabled or not is_instance_valid(target) or visible or game.player.jump_in_progress:
		return false
	if game.station_distance(target) > game.station_reach() or not target.is_available():
		return false
	var id: String = target.station_id
	if game.campaign.reserves_action(id):
		return false
	var exp: Dictionary = game.expedition.state
	var scrap := int(exp.scrap)
	match id:
		"beacon":
			if game.island_events.current == "sparks":
				return open_repair(target, "sparks")
			var restart: bool = game.night_raids.sabotaged or (game.campaign.enabled and game.campaign.state.blackout)
			var fueled: bool = game.inventory.fuel >= 1 or (game.campaign.enabled and int(game.campaign.state.beacon_charge) > 0)
			if not game.lighthouse_on and (restart or fueled):
				return open_repair(target, "beacon")
		"transmitter":
			if game.day >= 4 and not exp.signal and exp.tools and exp.battery and scrap >= 2:
				return open_repair(target, id)
		"pump":
			if game.day >= 3 and not exp.pump and exp.tools and game.inventory.wood >= 1 and scrap >= 2:
				return open_repair(target, id)
		"ship_engine":
			if game.day >= 6 and not exp.engine and exp.tools and scrap >= 4:
				return open_repair(target, id)
		"ship_hull":
			if game.day >= 5 and not exp.hull and exp.tools and game.inventory.wood >= 5 and scrap >= 2:
				return open_repair(target, id)
		"cook":
			if not game.fish_items.is_empty():
				return open_cook(target)
		"quarry":
			if exp.tools and game.homestead.quarry_used < game.homestead.QUARRY_DAILY:
				return open_repair(target, "quarry")
		"fire":
			var lit: bool = int(exp.fire_day) > 0 and int(exp.fire_day) >= int(exp.last_dawn)
			if not lit and game.inventory.wood >= 1:
				return open_fire(target)
	return false

func _begin(next: Mode, target: Area3D, id: String) -> void:
	mode = next
	station = target
	kind = id
	clock = 0
	result_time = 0
	result_text = ""
	success = false
	sparks.clear()
	game.paused = true
	game.player.enabled = false
	game.player.velocity = Vector3.ZERO
	show()

func open_repair(target: Area3D, id: String) -> bool:
	_begin(Mode.REPAIR, target, id)
	hits = 0
	misses = 0
	perfect = false
	needle = 0
	needle_speed = 2.0 + minf(1.6, game.day * .09) + (0.5 if id == "sparks" else 0.0)
	sector_width = clampf(.75 - game.day * .02, .42, .75)
	_new_sector()
	return true

func open_cook(target: Area3D) -> bool:
	_begin(Mode.COOK, target, "cook")
	side = 0
	doneness = 0
	sides_good = 0
	burnt = false
	return true

func open_fire(target: Area3D) -> bool:
	_begin(Mode.FIRE, target, "fire")
	stage = 0
	striker = 0
	embers = 0
	flame = 0
	steady = 0
	blowing = false
	return true

func _new_sector() -> void:
	sector = fmod(needle + randf_range(1.6, 4.4), TAU)

func handle(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.physical_keycode == KEY_SPACE:
			blowing = event.pressed
			if event.pressed and not event.echo:
				act()
		elif event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			cancel()
		elif event.pressed and not event.echo and event.physical_keycode == KEY_E:
			act()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		blowing = event.pressed
		if event.pressed:
			act()

func act() -> void:
	if result_time > 0:
		return
	match mode:
		Mode.REPAIR:
			var diff := absf(angle_difference(needle, sector))
			if diff <= sector_width * .5:
				hits += 1
				flash = .25
				_burst(Color("ffe29a"), 14)
				game.sound.interact("beacon")
				if hits >= 3:
					perfect = misses == 0
					_finish(true, "Готово! " + String(REPAIRS[kind].title) + " — успешно." + (" Чисто, без промахов!" if perfect else ""))
				else:
					_new_sector()
					needle_speed *= 1.12
			else:
				misses += 1
				flash = -.3
				_burst(RED, 22)
				game.camera_shake = maxf(game.camera_shake, .35)
				game.sound.cue("dispel")
				if misses >= 3:
					_finish(false, "Короткое замыкание! Отдышитесь и попробуйте снова (E).")
		Mode.COOK:
			_flip()
		Mode.FIRE:
			if stage == 0:
				var diff := absf(striker - .5)
				if diff < .12:
					embers += 1
					_burst(Color("ffb35c"), 18)
					game.sound.interact("wood")
					if embers >= 3:
						stage = 1
				else:
					_burst(Color(.6, .6, .6), 6)

func _flip() -> void:
	if side >= 2:
		return
	if doneness >= .6 and doneness <= .85:
		sides_good += 1
		_burst(Color("ffcf7a"), 12)
	elif doneness < .6:
		_burst(Color(.8, .8, .8), 6)
	side += 1
	doneness = 0
	game.sound.interact("cook")
	if side >= 2:
		cook_result = "burnt" if burnt else ("perfect" if sides_good == 2 else "ok")
		var text: String = {"perfect":"Золотистая корочка! Сытнее обычного.","ok":"Рыба готова.","burnt":"Подгорело… Есть можно, но сытость меньше."}[cook_result]
		_finish(true, text)

func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	flash = move_toward(flash, 0, delta)
	for spark in sparks:
		spark.p += spark.v * delta
		spark.v.y += 260 * delta
		spark.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0)
	if result_time > 0:
		result_time -= delta
		if result_time <= 0:
			_close_and_apply()
		queue_redraw()
		return
	match mode:
		Mode.REPAIR:
			needle = fmod(needle + needle_speed * delta, TAU)
			if kind == "sparks" and clock > 14:
				_finish(false, "Проводка перегрелась. Попробуйте ещё раз (E).")
		Mode.COOK:
			doneness += delta * (0.32 + game.day * 0.004)
			if doneness > 1.0:
				burnt = true
				doneness = 0
				side += 1
				_burst(Color(.3, .3, .3), 16)
				if side >= 2:
					cook_result = "burnt"
					_finish(true, "Подгорело… Есть можно, но сытость меньше.")
		Mode.FIRE:
			if stage == 0:
				striker = .5 + .5 * sin(clock * 3.4)
			else:
				var held := blowing or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
				flame = clampf(flame + delta * (.42 if held else -.3), 0, 1)
				if flame >= .45 and flame <= .78:
					steady += delta
					if randf() < .3:
						_burst(Color("ff9a3c"), 2)
				if steady >= 2.4:
					_finish(true, "Костёр разгорелся! Тени боятся его света до утра.")
				elif flame >= 1.0:
					flame = .2
					steady = maxf(0, steady - .8)
					_burst(Color(.5, .5, .5), 10)
	queue_redraw()

func _finish(ok: bool, text: String) -> void:
	success = ok
	result_text = text
	result_time = 1.1 if ok else 1.6
	if ok:
		game.sound.cue("chime")

func _close_and_apply() -> void:
	var target := station
	var ok := success
	var finished_mode := mode
	close()
	if not ok or not is_instance_valid(target):
		return
	game.interaction_cooldown = 0
	game.minigame_result = cook_result if finished_mode == Mode.COOK else ("done" if perfect else "ok")
	if game.attempt_interaction(target):
		game.player.play_gesture("interact")
	game.minigame_result = ""

func cancel() -> void:
	close()
	game.notify("Работа отложена. Ресурсы не потрачены.", 3)

func close() -> void:
	hide()
	mode = Mode.NONE
	blowing = false
	game.paused = false
	game.player.enabled = game.playing and not game.finished

func _burst(color: Color, count: int) -> void:
	var center := _center()
	for i in count:
		var angle := randf() * TAU
		sparks.append({"p":center + Vector2(cos(angle), sin(angle)) * 10, "v":Vector2(cos(angle), sin(angle) - .8) * randf_range(80, 260), "life":randf_range(.3, .8), "c":color})

func _center() -> Vector2:
	return get_viewport_rect().size * .5 + Vector2(0, 10)

## Подсказка в две строки по центру окна, чтобы длинный текст не обрезался.
func _hint(content: String, at: Vector2) -> void:
	var words := content.split(" ")
	var lines := PackedStringArray()
	var line := ""
	for word in words:
		var trial := word if line.is_empty() else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > 600 and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = trial
	lines.append(line)
	for i in lines.size():
		_text(lines[i], at + Vector2(0, i * 19), 14, GOLD)

func _text(content: String, at: Vector2, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, width := 640.0) -> void:
	draw_string(font, at + Vector2(-width * .5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0, 0), content, align, width, size_px, color)

func _draw() -> void:
	if not visible:
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.025, 0.03, .72))
	var box := Rect2(view.x * .5 - 340, view.y * .5 - 250, 680, 500)
	draw_rect(box, INK)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 3)), GOLD)
	var c := _center()
	match mode:
		Mode.REPAIR: _draw_repair(box, c)
		Mode.COOK: _draw_cook(box, c)
		Mode.FIRE: _draw_fire(box, c)
	for spark in sparks:
		draw_circle(spark.p, 2.5, Color(spark.c.r, spark.c.g, spark.c.b, clampf(spark.life * 2, 0, 1)))
	if result_time > 0:
		_text(result_text, Vector2(view.x * .5, box.end.y - 70), 20, TEAL if success else RED)
	_text("Пробел / ЛКМ — действие   ·   Esc — отложить", Vector2(view.x * .5, box.end.y - 22), 13, Color(PAPER.r, PAPER.g, PAPER.b, .6))

func _draw_repair(box: Rect2, c: Vector2) -> void:
	var info: Dictionary = REPAIRS.get(kind, REPAIRS.beacon)
	_text(String(info.title).to_upper(), Vector2(c.x, box.position.y + 44), 26, PAPER)
	_hint(String(info.hint), Vector2(c.x, box.position.y + 74))
	var radius := 120.0
	var tint := Color(1, .85, .5, .18) if flash > 0 else (Color(1, .3, .2, .22) if flash < 0 else Color(1, 1, 1, .05))
	draw_circle(c, radius + 14, tint)
	draw_arc(c, radius, 0, TAU, 96, Color(1, 1, 1, .25), 10)
	draw_arc(c, radius, sector - sector_width * .5, sector + sector_width * .5, 24, Color("4fd08a"), 12)
	for i in 24:
		var a := i * TAU / 24
		draw_line(c + Vector2(cos(a), sin(a)) * (radius - 22), c + Vector2(cos(a), sin(a)) * (radius - 12), Color(1, 1, 1, .25), 2)
	draw_line(c, c + Vector2(cos(needle), sin(needle)) * (radius + 6), Color("ffe29a"), 4)
	draw_circle(c, 10, GOLD)
	for i in 3:
		var at := Vector2(c.x - 40 + i * 40, c.y + radius + 48)
		draw_circle(at, 11, TEAL if i < hits else Color(1, 1, 1, .15))
	for i in misses:
		_text("✗", Vector2(c.x + 110 + i * 22, c.y + radius + 56), 20, RED, HORIZONTAL_ALIGNMENT_LEFT, 30)

func _draw_cook(box: Rect2, c: Vector2) -> void:
	_text("ЖАРКА РЫБЫ", Vector2(c.x, box.position.y + 44), 26, PAPER)
	_hint("Переверните рыбу (пробел), когда шкала в золотом окне. Две стороны — две попытки.", Vector2(c.x, box.position.y + 74))
	var pan := c + Vector2(0, 10)
	draw_circle(pan, 118, Color("2b2b2b"))
	draw_circle(pan, 104, Color("3a3a3a"))
	draw_line(pan + Vector2(104, 0), pan + Vector2(230, -6), Color("4a3a2a"), 16)
	var cooked := Color("c9a46a").lerp(Color("7a4a1e"), clampf(doneness * 1.1, 0, 1)) if not burnt or side < 2 else Color("2a1c12")
	var body := PackedVector2Array()
	for i in 32:
		var a := i * TAU / 32
		body.append(pan + Vector2(cos(a) * 70, sin(a) * 26))
	draw_colored_polygon(body, cooked)
	draw_colored_polygon(PackedVector2Array([pan + Vector2(62, 0), pan + Vector2(100, -24), pan + Vector2(100, 24)]), cooked.darkened(.15))
	draw_circle(pan + Vector2(-46, -6), 4, Color(0, 0, 0, .7))
	if doneness > .3:
		for i in 3:
			var wisp := pan + Vector2(-30 + i * 30, -40 - fmod(clock * 40 + i * 20, 60))
			draw_circle(wisp, 6, Color(1, 1, 1, .08))
	var bar := Rect2(c.x - 220, c.y + 150, 440, 16)
	draw_rect(bar, Color(1, 1, 1, .1))
	draw_rect(Rect2(bar.position.x + bar.size.x * .6, bar.position.y, bar.size.x * .25, bar.size.y), Color("e8ba64", .55))
	draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x * clampf(doneness, 0, 1), bar.size.y), Color("ffcf7a") if doneness < .85 else RED)
	_text("Сторона %d из 2   ·   удачных: %d" % [mini(side + 1, 2), sides_good], Vector2(c.x, bar.end.y + 26), 15, PAPER)

func _draw_fire(box: Rect2, c: Vector2) -> void:
	_text("РОЗЖИГ КОСТРА", Vector2(c.x, box.position.y + 44), 26, PAPER)
	var hint := "Высеките три искры: жмите, когда кресало над трутом." if stage == 0 else "Раздувайте огонь: держите пробел, не давайте пламени погаснуть или разгореться слишком сильно."
	_hint(hint, Vector2(c.x, box.position.y + 74))
	var base := c + Vector2(0, 70)
	for i in 5:
		var a := -0.5 + i * .25
		draw_line(base + Vector2(cos(a + PI * .5) * -70, 10), base + Vector2(cos(a + PI * .5) * 70, -14), Color("6b4a2a"), 10)
	draw_circle(base + Vector2(0, -6), 18, Color("8a6a3a"))
	if stage == 0:
		var x := lerpf(c.x - 200, c.x + 200, striker)
		draw_rect(Rect2(c.x - 24, base.y - 120, 48, 8), Color("4fd08a", .6))
		draw_rect(Rect2(x - 30, base.y - 130, 60, 14), Color("9aa3a8"))
		for i in 3:
			draw_circle(Vector2(c.x - 40 + i * 40, box.end.y - 110), 10, Color("ffb35c") if i < embers else Color(1, 1, 1, .15))
	else:
		var height := 40.0 + flame * 150.0
		for layer in 3:
			var w := (60.0 - layer * 16) * (0.6 + flame * .6)
			var h := height * (1.0 - layer * .22) * (0.92 + .08 * sin(clock * 18 + layer))
			var col: Color = [Color("ff6a2a"), Color("ffb347"), Color("fff1a8")][layer]
			draw_colored_polygon(PackedVector2Array([base + Vector2(-w, -4), base + Vector2(0, -h), base + Vector2(w, -4)]), Color(col.r, col.g, col.b, .9))
		var bar := Rect2(c.x - 220, box.end.y - 128, 440, 14)
		draw_rect(bar, Color(1, 1, 1, .1))
		draw_rect(Rect2(bar.position.x + bar.size.x * .45, bar.position.y, bar.size.x * .33, bar.size.y), Color("4fd08a", .5))
		draw_rect(Rect2(bar.position.x + bar.size.x * flame - 3, bar.position.y - 4, 6, bar.size.y + 8), Color("ffe29a"))
		_text("Ровное пламя %.1f / 2,4 с" % steady, Vector2(c.x, bar.end.y + 22), 14, PAPER)
