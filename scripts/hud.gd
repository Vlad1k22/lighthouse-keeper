extends CanvasLayer
const MAP = preload("res://scripts/island_map.gd")
const FISHING_UI = preload("res://scripts/fishing_ui.gd")
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
var meal_label: Label
var prompt_label: Label
var movement_help: Label
var message_label: Label
var menu_title: Label
var menu_subtitle: Label
var start_button: Button
var continue_button: Button
var save_button: Button
var exit_button: Button
var demo_button: Button
var first_shift_button: Button
var title_button: Button
var settings_button: Button
var settings_panel: Control
var backpack: Control
var salvage: Control
var fieldwork: Control
var tuner: Control
var warmth_label: Label
var menu_art: TextureRect
var title_mark: TextureRect
var ending_stamp: Label
const SETTINGS_PANEL = preload("res://scripts/settings_panel.gd")
const BACKPACK = preload("res://scripts/backpack.gd")
const SALVAGE = preload("res://scripts/salvage_game.gd")
const FIELDWORK = preload("res://scripts/fieldwork.gd")
const RADIO_TUNER = preload("res://scripts/radio_tuner.gd")
const HORIZON = preload("res://assets/ui/end_horizon.svg")
const BRAND_MARK = preload("res://assets/ui/lighthouse_mark.svg")
var demo_hint_panel: Panel
var demo_hint_label: Label
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var sanity_bar: ProgressBar
var stamina_bar: ProgressBar
var fishing_overlay: Control
var danger: ColorRect
var atmosphere: ColorRect
var reader: Control
var reader_title: Label
var reader_text: RichTextLabel
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
	fishing_overlay = Control.new()
	fishing_overlay.set_script(FISHING_UI)
	fishing_overlay.game = game
	root.add_child(fishing_overlay)
	settings_panel = SETTINGS_PANEL.new()
	root.add_child(settings_panel)
	settings_panel.setup(self,game.preferences)
	backpack = BACKPACK.new()
	root.add_child(backpack)
	backpack.setup(self)
	salvage = SALVAGE.new()
	root.add_child(salvage)
	salvage.setup(self)
	fieldwork = FIELDWORK.new()
	root.add_child(fieldwork)
	fieldwork.setup(self)
	tuner = RADIO_TUNER.new()
	root.add_child(tuner)
	tuner.setup(self)

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
	text(game_ui, "ПУТЬ С ОСТРОВА   /   ОСТРОВ СЕВЕРНЫЙ", Rect2(33, 59, 420, 22), 12, GOLD)
	panel(game_ui, Rect2(32, 119, 300, 320))
	text(game_ui, "ЖУРНАЛ СМОТРИТЕЛЯ", Rect2(51, 137, 270, 25), 13, GOLD)
	task_label = text(game_ui, "", Rect2(51, 177, 263, 220), 14)
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
	warmth_label = text(game_ui,"",Rect2(332,828,118,15),10,MUTED)
	panel(game_ui, Rect2(1017, 727, 391, 144))
	text(game_ui, "РЮКЗАК · B", Rect2(1036, 740, 200, 19), 11, GOLD)
	inventory_label = text(game_ui, "", Rect2(1036, 766, 354, 40), 15)
	meal_label = text(game_ui, "", Rect2(1036, 815, 354, 43), 12)
	var prompt_bg := panel(game_ui, Rect2(491, 808, 505, 56))
	prompt_bg.name = "PromptBackground"
	prompt_label = text(game_ui, "", Rect2(508, 819, 474, 31), 14)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label = text(game_ui, "", Rect2(410, 704, 600, 65), 18, GOLD)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_shadow_color", Color("102b32"))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	demo_hint_panel = panel(game_ui, Rect2(385, 25, 670, 58))
	demo_hint_label = text(demo_hint_panel, "", Rect2(16, 6, 638, 46), 16, PAPER)
	demo_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo_hint_panel.hide()
	movement_help = text(game_ui, "", Rect2(32, 880, 1050, 18), 11, MUTED)
	text(game_ui, "O обзор  ·  M цели  ·  J записи", Rect2(1132, 880, 276, 18), 11, MUTED)
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
	menu_art = TextureRect.new()
	menu_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_art.texture = HORIZON
	menu.add_child(menu_art)
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
	title_mark = TextureRect.new()
	title_mark.texture = BRAND_MARK
	title_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_mark.size = Vector2(104,104)
	title_mark.position = Vector2(1228,68)
	title_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(title_mark)
	text(menu, "СЕВЕРНЫЙ БЕРЕГ    /    ИГРА НА GODOT", Rect2(66, 108, 650, 26), 13, GOLD)
	menu_title = text(menu, "Смотритель\nмаяка", Rect2(60, 203, 650, 195), 71, PAPER)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif"])
	menu_title.add_theme_font_override("font", serif)
	menu_subtitle = text(menu, "Один остров. Одна смена.\nСохраните свет — и дождитесь рассвета.", Rect2(66, 426, 530, 67), 20, MUTED)
	menu_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = make_button(menu, "Начать смену", Vector2(66, 535), func(): game.start_or_resume(), true)
	first_shift_button = make_button(menu, "Демо · Первая смена", Vector2(66, 601), func(): game.start_first_shift_demo())
	demo_button = make_button(menu, "Свободный осмотр · гавань", Vector2(402, 601), func(): game.start_demo())
	demo_button.size.x = 380
	title_button = make_button(menu, "В главное меню", Vector2(66, 601), func(): game.return_to_title())
	settings_button = make_button(menu, "Настройки", Vector2(402, 667), func(): settings_panel.open())
	continue_button = make_button(menu, "Продолжить сохранение", Vector2(66, 601), func(): game.load_game())
	save_button = make_button(menu, "Сохранить смену", Vector2(66, 667), func(): game.save_game())
	exit_button = make_button(menu, "Выйти из игры", Vector2(66, 733), func(): get_tree().quit())
	menu.move_child(continue_button, start_button.get_index() + 1)
	var focus := style(Color.TRANSPARENT, Color("c6a873"), 9)
	focus.draw_center = false
	focus.set_border_width_all(2)
	for button in [start_button, first_shift_button, demo_button, title_button, settings_button, continue_button, save_button, exit_button]:
		button.add_theme_stylebox_override("focus", focus)
	text(menu, "Учебная демоверсия  •  Путь с острова\nВлад Людкевич · Костя Котельников\nАндрей Виговский · Артём Артамонов", Rect2(66, 809, 680, 69), 12, MUTED)
	ending_stamp = text(menu, "", Rect2(785,778,555,48), 17, PAPER)
	ending_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	show_menu("title")

func show_menu(mode: String) -> void:
	if is_instance_valid(reader):
		reader.hide()
	menu.show()
	game_ui.hide()
	game.sound.set_music(mode)
	menu_art.visible = mode in ["win","demo_win"]
	title_mark.visible = mode in ["title","win","demo_win"]
	ending_stamp.visible = menu_art.visible
	ending_stamp.text = "СВЯЗЬ ПОДТВЕРЖДЕНА   /   06:45" if mode=="demo_win" else "КАТЕР «СЕВЕРНЫЙ»   /   КУРС НА МАТЕРИК"
	var in_episode: bool = game.first_shift_demo.active()
	save_button.visible = mode == "pause" and not in_episode
	demo_button.visible = mode == "title"
	first_shift_button.visible = mode == "title"
	settings_button.visible = mode in ["title","pause"]
	title_button.visible = in_episode and mode in ["pause","demo_loss"]
	continue_button.visible = not in_episode and FileAccess.file_exists(game.save_path)
	layout_menu_buttons(mode)
	if mode == "pause":
		menu_title.text = "Смена\nна паузе"
		menu_subtitle.text = "Время и ночные события остановлены.\nEsc — продолжить." if in_episode else "Время и ночные события остановлены.\nEsc — продолжить. F9 — сохранить, F10 — загрузить."
		start_button.text = "Вернуться на остров"
	elif mode == "demo_win":
		menu_title.text = "Первая смена\nзавершена"
		menu_subtitle.text = "Маяк работает. Ночь пережита.\n«Берег-четыре» подтвердил связь."
		start_button.text = "В главное меню"
	elif mode == "demo_loss":
		menu_title.text = "Смена\nпрервана"
		menu_subtitle.text = "Вернитесь к началу демонстрации."
		start_button.text = "Повторить демо"
	elif mode == "win":
		menu_title.text = "Курс\nна материк"
		menu_subtitle.text = ("День %d. Контрольная группа принята.\nВы держитесь курса по приборам. Голоса остаются на острове." if game.campaign.enabled else "День %d. Катер исправен, сигнал принят.\nВы оставили остров позади. Или вам так кажется?") % game.day
		start_button.text = "Начать новую смену"
	elif mode == "loss":
		menu_title.text = "Остров\nне отпускает"
		menu_subtitle.text = "Смена закончилась. Свет и укреплённая\nхижина помогут пережить следующую попытку."
		start_button.text = "Повторить этот день" if game.campaign.enabled and FileAccess.file_exists(game.checkpoint_path) else "Попробовать снова"
		if game.campaign.enabled:menu_subtitle.text = "Начало дня сохранено автоматически.\nПовторите только последнее дежурство."
	else:
		menu_title.text = "Смотритель\nмаяка"
		menu_subtitle.text = "Свет, записи и ложные голоса.\nСюжетная кампания на %d дней." % game.campaign.SHORT_DAYS
		start_button.text = "Начать смену"

func layout_menu_buttons(mode: String) -> void:
	if mode == "title":
		var y := 510
		for button in [start_button, continue_button, first_shift_button, demo_button]:
			if button.visible:
				button.position = Vector2(66, y)
				button.size = Vector2(400, 47)
				y += 55
		settings_button.position = Vector2(66, y + 6)
		exit_button.position = Vector2(272, y + 6)
		settings_button.size = Vector2(194, 44)
		exit_button.size = settings_button.size
		return
	start_button.position = Vector2(66, 535)
	settings_button.position = Vector2(402, 535)
	continue_button.position = Vector2(66, 601)
	exit_button.position = Vector2(66, 733 if mode == "pause" else (667 if continue_button.visible or title_button.visible else 601))
	for button in [start_button, settings_button, continue_button, exit_button]:
		button.size = Vector2(310, 51)

func show_game() -> void:
	if is_instance_valid(reader):
		reader.hide()
	menu.hide()
	game.sound.set_music("game")
	game_ui.show()

func build_reader() -> void:
	reader = Control.new()
	reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(reader)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.07, 0.09, 0.72)
	reader.add_child(shade)
	panel(reader, Rect2(330, 118, 780, 664), Color("d9d0b4"))
	text(reader, "ОСТРОВ СЕВЕРНЫЙ    /    ЛИЧНЫЕ ЗАПИСИ", Rect2(368, 150, 700, 23), 12, Color("72735e"))
	reader_title = text(reader, "", Rect2(368, 186, 704, 80), 32, INK)
	reader_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader_title.max_lines_visible = 2
	reader_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif"])
	reader_title.add_theme_font_override("font", serif)
	reader_text = RichTextLabel.new()
	reader_text.position = Vector2(368, 278)
	reader_text.size = Vector2(704, 378)
	reader_text.clip_contents = true
	reader_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader_text.add_theme_font_size_override("normal_font_size", 20)
	reader_text.add_theme_color_override("default_color", Color("30484a"))
	reader_text.add_theme_constant_override("line_separation", 3)
	var padding := StyleBoxEmpty.new()
	padding.content_margin_right = 12
	reader_text.add_theme_stylebox_override("normal", padding)
	reader.add_child(reader_text)
	var scrollbar := reader_text.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", style(Color("c9c0a4"), Color.TRANSPARENT, 4))
	scrollbar.add_theme_stylebox_override("grabber", style(Color("777f6b"), Color.TRANSPARENT, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", style(Color("596552"), Color.TRANSPARENT, 4))
	scrollbar.add_theme_stylebox_override("grabber_pressed", style(Color("465947"), Color.TRANSPARENT, 4))
	panel(reader, Rect2(368, 669, 704, 1), Color("b5ac93"))
	reader_count = text(reader, "", Rect2(368, 685, 550, 24), 12, Color("72735e"))
	previous_page = make_button(reader, "←", Vector2(981, 678), func(): game.turn_journal_page(-1))
	previous_page.size = Vector2(38, 38)
	next_page = make_button(reader, "→", Vector2(1034, 678), func(): game.turn_journal_page(1))
	next_page.size = Vector2(38, 38)
	var close_button := make_button(reader, "Вернуться на остров  ·  E / Esc", Vector2(368, 722), func(): game.close_journal(), true)
	close_button.size = Vector2(410, 42)
	reader.hide()

func show_journal(title_content: String, body: String, count: String) -> void:
	menu.hide()
	game_ui.hide()
	reader.show()
	reader_title.text = title_content
	reader_text.text = body
	reader_text.scroll_to_line(0)
	reader_count.text = count
	previous_page.visible = game.journal_entries.size() > 1
	next_page.visible = game.journal_entries.size() > 1

func scroll_journal(direction: int) -> void:
	reader_text.get_v_scroll_bar().value += direction * 48

func refresh() -> void:
	var minutes := int(game.hour * 60) % 1440
	clock_label.text = "ДЕНЬ %02d    %02d:%02d" % [game.day, minutes / 60, minutes % 60]
	status_label.text = ("НОЧЬ · ДОЖДЬ" if game.coastal_life.rain_strength > 0.2 else "НОЧЬ · ДЕРЖИТЕСЬ СВЕТА") if game.is_night() else game.coastal_life.weather_label()
	movement_help.text = "WASD ходить  ·  Shift бег  ·  Пробел прыжок  ·  E действие  ·  F фонарь  ·  R еда  ·  M карта  ·  J журнал  ·  Esc меню"
	if game.lighthouse_interior.active:
		status_label.text = "МАЯК · ВНУТРИ"
		movement_help.text = "WASD ходить по лестнице  ·  E действие  ·  F фонарь  ·  R еда  ·  M карта  ·  J журнал  ·  Esc меню"
	var room_title: String = game.building_interiors.title(game.player.position)
	if not room_title.is_empty():
		status_label.text = room_title
		movement_help.text = "WASD ходить  ·  E действие  ·  F фонарь  ·  R еда  ·  M карта  ·  J журнал  ·  Esc меню"
	task_label.text = game.expedition.tasks()
	demo_hint_label.text = game.first_shift_demo.hint()
	demo_hint_panel.visible = not demo_hint_label.text.is_empty() and not game.first_shift_demo.is_open()
	health_bar.value = game.health
	hunger_bar.value = game.hunger
	sanity_bar.value = game.sanity
	stamina_bar.value = game.player.stamina
	inventory_label.text = "Топливо %d   Дерево %d   Детали %d\nРыба %d   Еда %d   Вода %d/%d" % [game.inventory.fuel, game.inventory.wood, int(game.expedition.state.scrap), game.inventory.fish, game.inventory.food, game.survival.water, game.survival.FLASK_CAPACITY]
	warmth_label.visible = game.survival.exposure_enabled()
	warmth_label.text = "ТЕПЛО %d%%" % roundi(game.survival.warmth)
	if not game.food_items.is_empty():
		var meal: Dictionary = game.food_items[game.selected_food]
		var benefit: Dictionary = game.PROVISIONS.bonuses(meal)
		meal_label.text = "R: %s\n+%d ЗДР · +%d СЫТ · Q — выбор еды" % [game.PROVISIONS.label(meal), benefit.health, benefit.hunger]
		meal_label.add_theme_color_override("font_color", game.PROVISIONS.rarity_color(meal))
	else:
		meal_label.text = "Готовой еды нет. Рыбу можно приготовить на печи."
	prompt_label.text = "[E] " + game.nearest_station.display_name if is_instance_valid(game.nearest_station) else "Исследуйте остров · ◆ места действий"
	if not is_instance_valid(game.nearest_station) and not game.building_interiors.active.is_empty():
		prompt_label.text = "◇ Выход  ·  ◆ Места действий"
	if is_instance_valid(game.nearest_station) and game.campaign.enabled:
		prompt_label.text = "[E] "+game.campaign.prompt(game.nearest_station.station_id,game.nearest_station.display_name)
	if is_instance_valid(game.nearest_station) and game.nearest_station.station_id=="scrap" and salvage.station_in_reach()!=null:
		prompt_label.text = "[E] Забрать детали   ·   [G] Аккуратный разбор"
	if is_instance_valid(game.nearest_station) and game.nearest_station.station_id == "cook" and not game.fish_items.is_empty():
		var raw_fish: Dictionary = game.fish_items[game.selected_fish]
		prompt_label.text = "[E] %s %d г · [K] рецепты" % [raw_fish.name, raw_fish.weight]
	var lighthouse_prompt: String = game.lighthouse_interior.prompt(game.player.position)
	if not lighthouse_prompt.is_empty():
		prompt_label.text = lighthouse_prompt
	var building_prompt: String = game.building_interiors.prompt(game.player.position)
	if not building_prompt.is_empty():
		prompt_label.text = building_prompt
	var extra_prompt: String = game.extras.prompt()
	if not extra_prompt.is_empty():
		prompt_label.text = extra_prompt
	if is_instance_valid(game.nearest_station) and lighthouse_prompt.is_empty() and extra_prompt.is_empty():
		var id: String = game.nearest_station.station_id
		if fieldwork.available_at(game.nearest_station):
			prompt_label.text += "  ·  [G] " + ("Давление насоса" if id=="depot" else "Сухие поленья")
		elif id=="cook":
			prompt_label.text = "[E] Печь  ·  [K] Рецепты и обогрев"
		elif id=="radio" or (id=="transmitter" and game.expedition.state.signal):
			prompt_label.text += "  ·  [U] Частоты"
		elif id=="pump" and game.survival.can_refill():
			prompt_label.text += "  ·  [H] Наполнить флягу"
	if game.expedition.sailing:
		prompt_label.text = "Курс на материк · переход к внешнему бую"
	fishing_overlay.visible = game.fishing.is_open()
	if fishing_overlay.visible:
		fishing_overlay.queue_redraw()
	message_label.text = game.message if game.message_time > 0 else ""
	message_label.visible = not game.fishing.is_open()
	danger.color.a = maxf(0.0, danger.color.a - get_process_delta_time() * 0.8)
	atmosphere.material.set_shader_parameter("night", game.coastal_life.night_strength)
	atmosphere.material.set_shader_parameter("stress", clampf((55 - game.sanity) / 55, 0, 1))
