extends CanvasLayer
const MAP = preload("res://scripts/island_map.gd")
const INK := Color("102b32")
const PAPER := Color("e9e3ce")
const GOLD := Color("deb777")
const MUTED := Color("97b1ac")
var game: Node
var root: Control
var game_ui: Control
var menu: Control
var clock_label: Label
var task_label: Label
var status_label: Label
var inventory_label: Label
var prompt_label: Label
var message_label: Label
var menu_title: Label
var menu_subtitle: Label
var start_button: Button
var continue_button: Button
var save_button: Button
var exit_button: Button
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var sanity_bar: ProgressBar
var stamina_bar: ProgressBar
var work_bar: ProgressBar
var danger: ColorRect
var atmosphere: ColorRect
var reader: Control
var reader_title: Label
var reader_text: Label
var reader_count: Label
var previous_page: Button
var next_page: Button

func _ready() -> void:
	game = get_parent()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	atmosphere = ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atmosphere_material := ShaderMaterial.new()
	atmosphere_material.shader = load("res://shaders/screen_atmosphere.gdshader")
	atmosphere.material = atmosphere_material
	root.add_child(atmosphere)
	build_game_ui()
	build_menu()
	build_reader()

func style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 9) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func panel(parent: Control, rect: Rect2, color: Color = Color(0.035, 0.11, 0.14, 0.87)) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", style(color, Color(0.5, 0.67, 0.63, 0.17)))
	parent.add_child(node)
	return node

func text(parent: Control, content: String, rect: Rect2, font_size: int = 18, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = content
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func progress(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	var background := style(Color("253e42"), Color.TRANSPARENT, 3)
	var fill := style(color, Color.TRANSPARENT, 3)
	for box in [background, fill]:
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	bar.size = rect.size
	return bar

func build_game_ui() -> void:
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_ui)
	text(game_ui, "СМОТРИТЕЛЬ МАЯКА", Rect2(32, 25, 440, 30), 22, PAPER)
	text(game_ui, "ПЕРВАЯ СМЕНА   /   ОСТРОВ СЕВЕРНЫЙ", Rect2(33, 59, 420, 22), 12, GOLD)
	panel(game_ui, Rect2(32, 119, 300, 295))
	text(game_ui, "ЖУРНАЛ СМОТРИТЕЛЯ", Rect2(51, 137, 270, 25), 13, GOLD)
	task_label = text(game_ui, "", Rect2(51, 177, 263, 220), 16)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel(game_ui, Rect2(1150, 25, 258, 83))
	clock_label = text(game_ui, "", Rect2(1168, 38, 224, 33), 23)
	status_label = text(game_ui, "", Rect2(1168, 77, 225, 20), 12, GOLD)
	panel(game_ui, Rect2(1236, 124, 172, 155))
	var map := Control.new()
	map.set_script(MAP)
	map.set("game", game)
	map.position = Vector2(1236, 124)
	map.size = Vector2(172, 155)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(map)
	panel(game_ui, Rect2(32, 775, 438, 96))
	text(game_ui, "ЗДОРОВЬЕ", Rect2(51, 787, 130, 20), 11, MUTED)
	text(game_ui, "СЫТОСТЬ", Rect2(192, 787, 125, 20), 11, MUTED)
	text(game_ui, "РАССУДОК", Rect2(332, 787, 125, 20), 11, MUTED)
	health_bar = progress(game_ui, Rect2(51, 815, 118, 8), Color("c48e78"))
	hunger_bar = progress(game_ui, Rect2(192, 815, 118, 8), Color("d7b477"))
	sanity_bar = progress(game_ui, Rect2(332, 815, 118, 8), Color("7da8a3"))
	stamina_bar = progress(game_ui, Rect2(51, 847, 399, 4), Color("9cbca6"))
	text(game_ui, "ВЫНОСЛИВОСТЬ", Rect2(51, 828, 160, 15), 9, MUTED)
	panel(game_ui, Rect2(1017, 775, 391, 96))
	text(game_ui, "РЮКЗАК", Rect2(1036, 788, 200, 19), 11, GOLD)
	inventory_label = text(game_ui, "", Rect2(1036, 818, 354, 40), 15)
	var prompt_bg := panel(game_ui, Rect2(491, 808, 505, 56))
	prompt_bg.name = "PromptBackground"
	prompt_label = text(game_ui, "", Rect2(508, 819, 474, 31), 17)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	work_bar = progress(game_ui, Rect2(508, 856, 474, 4), GOLD)
	work_bar.hide()
	message_label = text(game_ui, "", Rect2(410, 704, 620, 65), 18, GOLD)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_shadow_color", Color("102b32"))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	text(game_ui, "WASD ходить  ·  Shift бег  ·  E действие  ·  F фонарь  ·  R еда  ·  J журнал  ·  Esc меню", Rect2(32, 880, 1050, 18), 11, MUTED)
	text(game_ui, "O обзор  ·  N ночь  ·  V погода", Rect2(1132, 880, 276, 18), 11, MUTED)
	danger = ColorRect.new()
	danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	danger.color = Color(0.5, 0.05, 0.03, 0)
	danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(danger)

func make_button(parent: Control, content: String, at: Vector2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = content
	node.position = at
	node.size = Vector2(310, 51)
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_color_override("font_color", INK if primary else PAPER)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_stylebox_override("normal", style(GOLD if primary else Color(0.06, 0.17, 0.19, 0.9), Color(0.6, 0.72, 0.67, 0.2)))
	node.add_theme_stylebox_override("hover", style(Color("ead2a0")))
	node.add_theme_stylebox_override("pressed", style(Color("b99763")))
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var veil := TextureRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.025, 0.085, 0.11, 0.97), Color(0.025, 0.085, 0.11, 0.82), Color(0.025, 0.085, 0.11, 0.0)])
	gradient.offsets = PackedFloat32Array([0, 0.34, 0.8])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 2
	veil.texture = texture
	menu.add_child(veil)
	text(menu, "СЕВЕРНЫЙ БЕРЕГ    /    ИГРА НА GODOT", Rect2(66, 108, 650, 26), 13, GOLD)
	menu_title = text(menu, "Смотритель\nмаяка", Rect2(60, 203, 650, 195), 71, PAPER)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif"])
	menu_title.add_theme_font_override("font", serif)
	menu_subtitle = text(menu, "Один остров. Одна смена.\nСохраните свет — и дождитесь рассвета.", Rect2(66, 426, 530, 67), 20, MUTED)
	menu_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = make_button(menu, "Начать смену", Vector2(66, 535), func(): game.start_shift(), true)
	continue_button = make_button(menu, "Продолжить сохранение", Vector2(66, 601), func(): game.load_game())
	save_button = make_button(menu, "Сохранить смену", Vector2(66, 667), func(): game.save_game())
	exit_button = make_button(menu, "Выйти из игры", Vector2(66, 733), func(): get_tree().quit())
	text(menu, "Учебная демоверсия  •  Первая смена\nВлад Людкевич · Костя Котельников\nАндрей Виговский · Артём Артамонов", Rect2(66, 809, 680, 69), 12, MUTED)
	show_menu("title")

func show_menu(mode: String) -> void:
	if is_instance_valid(reader):
		reader.hide()
	menu.show()
	game_ui.hide()
	save_button.visible = mode == "pause"
	continue_button.visible = FileAccess.file_exists(game.save_path)
	exit_button.position.y = 733 if mode == "pause" else (667 if continue_button.visible else 601)
	if mode == "pause":
		menu_title.text = "Смена\nна паузе"
		menu_subtitle.text = "Возвращайтесь, когда будете готовы.\nEsc — продолжить. N — сменить время для показа."
		start_button.text = "Вернуться на остров"
	elif mode == "win":
		menu_title.text = "До первого\nрассвета"
		menu_subtitle.text = "Маяк горит. Убежище укреплено.\nВы пережили первую ночь на острове."
		start_button.text = "Начать новую смену"
	elif mode == "loss":
		menu_title.text = "Остров\nне отпускает"
		menu_subtitle.text = "Смена закончилась. Свет и укреплённая\nхижина помогут пережить следующую попытку."
		start_button.text = "Попробовать снова"
	else:
		menu_title.text = "Смотритель\nмаяка"
		menu_subtitle.text = "Один остров. Одна смена.\nСохраните свет — и дождитесь рассвета."
		start_button.text = "Начать смену"

func show_game() -> void:
	if is_instance_valid(reader):
		reader.hide()
	menu.hide()
	game_ui.show()

func build_reader() -> void:
	reader = Control.new()
	reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(reader)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.07, 0.09, 0.72)
	reader.add_child(shade)
	panel(reader, Rect2(330, 167, 780, 566), Color("d9d0b4"))
	text(reader, "ОСТРОВ СЕВЕРНЫЙ    /    ЛИЧНЫЕ ЗАПИСИ", Rect2(368, 197, 700, 23), 12, Color("72735e"))
	reader_title = text(reader, "", Rect2(368, 245, 700, 57), 32, INK)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif"])
	reader_title.add_theme_font_override("font", serif)
	reader_text = text(reader, "", Rect2(368, 321, 700, 288), 20, Color("30484a"))
	reader_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader_text.add_theme_constant_override("line_spacing", 5)
	reader_count = text(reader, "", Rect2(368, 625, 550, 24), 12, Color("72735e"))
	previous_page = make_button(reader, "←", Vector2(1018, 618), func(): game.turn_journal_page(-1))
	previous_page.size = Vector2(32, 32)
	next_page = make_button(reader, "→", Vector2(1060, 618), func(): game.turn_journal_page(1))
	next_page.size = Vector2(32, 32)
	var close_button := make_button(reader, "Вернуться на остров  ·  E / Esc", Vector2(368, 668), func(): game.close_journal(), true)
	close_button.size = Vector2(410, 42)
	reader.hide()

func show_journal(title_content: String, body: String, count: String) -> void:
	menu.hide()
	game_ui.hide()
	reader.show()
	reader_title.text = title_content
	reader_text.text = body
	reader_count.text = count
	previous_page.visible = game.journal_entries.size() > 1
	next_page.visible = game.journal_entries.size() > 1

func refresh() -> void:
	var minutes := int(game.hour * 60) % 1440
	clock_label.text = "ДЕНЬ %02d    %02d:%02d" % [game.day, minutes / 60, minutes % 60]
	status_label.text = ("НОЧЬ · ДОЖДЬ" if game.coastal_life.rain_strength > 0.2 else "НОЧЬ · ДЕРЖИТЕСЬ СВЕТА") if game.is_night() else game.coastal_life.weather_label()
	var a := "✓" if game.fuel_found else "○"
	var b := "✓" if game.lighthouse_on else "○"
	var c := "✓" if game.barricade_built else "○"
	task_label.text = "%s Найти топливо\n%s Запустить маяк\n%s Укрепить хижину\n○ Дождаться рассвета\n\n%s" % [a, b, c, game.current_objective()]
	health_bar.value = game.health
	hunger_bar.value = game.hunger
	sanity_bar.value = game.sanity
	stamina_bar.value = game.player.stamina
	inventory_label.text = "Топливо %d   Дерево %d\nРыба %d        Еда %d" % [game.inventory.fuel, game.inventory.wood, game.inventory.fish, game.inventory.food]
	if game.busy_time > 0:
		prompt_label.text = "Рыбалка… дождитесь поклёвки"
		work_bar.show()
		work_bar.value = (1.0 - game.busy_time / 3.0) * 100
	else:
		work_bar.hide()
		prompt_label.text = "[E] " + game.nearest_station.display_name if is_instance_valid(game.nearest_station) else "Исследуйте остров · ◆ места действий"
	message_label.text = game.message if game.message_time > 0 else ""
	danger.color.a = maxf(0.0, danger.color.a - get_process_delta_time() * 0.8)
	atmosphere.material.set_shader_parameter("night", game.coastal_life.night_strength)
	atmosphere.material.set_shader_parameter("stress", clampf((55 - game.sanity) / 55, 0, 1))
