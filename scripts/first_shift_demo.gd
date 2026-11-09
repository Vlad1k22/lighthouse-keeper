extends RefCounted
## Standalone version of day one. It uses the same island, tasks and night event.
enum Stage { OFF, INTRO, WATCH, CONTACT, CONFIRMED }
const RADIO_CALL = preload("res://assets/audio/first_shift/radio_call.wav")
const RADIO_CONFIRM = preload("res://assets/audio/first_shift/radio_confirm.wav")
const LOG_ID := "demo:call_sign"
const LOG := {
	"title": "Памятка береговой станции",
	"text": "Береговая станция — «Берег-четыре».\nНаш маяк — «Северный».\n\nПрежде чем отвечать на распоряжение, сверьте позывной. Береговая станция проверяет связь и ждёт подтверждения. Если голос торопит выйти в море, держитесь на берегу."
}

var game: Node
var stage := Stage.OFF
var modal: Control
var heading: Label
var dialogue: Label
var response: Label
var primary: Button
var primary_style: StyleBox
var alternate: Button
var journal: Button
var voice: AudioStreamPlayer

func active() -> bool:
	return stage != Stage.OFF

func awaiting_contact() -> bool:
	return stage in [Stage.CONTACT, Stage.CONFIRMED]

func is_open() -> bool:
	return is_instance_valid(modal) and modal.visible

func reset() -> void:
	stage = Stage.OFF
	if is_instance_valid(modal):
		_stop_voice()
		modal.hide()

func show_intro() -> void:
	stage = Stage.INTRO
	_show("ПЕРВАЯ СМЕНА", "Вы прибыли на остров Северный. До темноты нужно запустить маяк и подготовить хижину. Утром береговая станция проверит связь.\n\nWASD — движение. E — действие. M — карта.", "Выйти на остров · E")

func begin_watch() -> void:
	if stage != Stage.INTRO:
		return
	stage = Stage.WATCH
	_resume()
	game.notify("Найдите канистру. Бирюзовый маркер на карте M показывает следующую цель.", 6)

func start_contact() -> void:
	stage = Stage.CONTACT
	game.campaign.state.night = false
	game.hour = 6.75
	game.was_night = false
	game.clear_enemies()
	if LOG_ID not in game.journal_entries:
		game.journal_entries.append(LOG_ID)
	game.sound.radio_signal()
	game.notify("Рассвет. Радио запрашивает ответ. Сверьте позывной в журнале J.", 8)

func intercept(id: String) -> int:
	if not awaiting_contact():
		return -1
	if id=="shelter":
		game.notify("Дежурство закончено. Ответьте береговой станции по радио.", 5)
		return 0
	if id!="radio":
		return -1
	if game.building_interiors.active!="cabin":
		game.notify("Ответьте по радио внутри хижины. Вход у двери на E.", 5)
		return 0
	open_radio()
	return 1

func open_radio() -> void:
	if stage != Stage.CONTACT:
		return
	game.extras.stop_record()
	_show("РАДИО · ВХОДЯЩИЙ СИГНАЛ", "«Северный, ответьте. Это береговая станция. Назовите наш позывной, чтобы подтвердить связь.»", "1 · Берег-четыре")
	alternate.show()
	journal.show()
	voice.stream = RADIO_CALL
	voice.play()

func choose(verified: bool) -> void:
	if stage != Stage.CONTACT or not is_open():
		return
	if not verified:
		response.text = "«Северный» — позывной маяка. Сверьте запись в журнале J."
		return
	stage = Stage.CONFIRMED
	_show("РАДИО · БЕРЕГ-ЧЕТЫРЕ", "«Северный, связь подтверждаю. Ваш свет виден с материка. Запишите время. На сегодня вы сделали всё, что могли.»", "Завершить смену · E")
	voice.stream = RADIO_CONFIRM
	voice.play()

func accept() -> void:
	match stage:
		Stage.INTRO: begin_watch()
		Stage.CONTACT: choose(true)
		Stage.CONFIRMED:
			_resume()
			game.finish_shift(true)

func read_log() -> void:
	if stage != Stage.CONTACT or not is_open():
		return
	_resume()
	game.open_journal()

func handle_key(key: Key) -> void:
	match stage:
		Stage.INTRO, Stage.CONFIRMED:
			if key in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
				accept()
			elif stage == Stage.INTRO and key == KEY_ESCAPE:
				game.return_to_title()
		Stage.CONTACT:
			match key:
				KEY_1, KEY_KP_1: choose(true)
				KEY_2, KEY_KP_2: choose(false)
				KEY_J: read_log()
				KEY_ESCAPE: _resume()

func _resume() -> void:
	_stop_voice()
	modal.hide()
	game.paused = false
	game.player.enabled = true

func _stop_voice() -> void:
	voice.stop()
	voice.stream = null

func _show(title: String, body: String, button: String) -> void:
	if not is_instance_valid(modal):
		_build()
	heading.text = title
	dialogue.text = body
	primary.text = button
	var choosing := stage == Stage.CONTACT
	primary.add_theme_stylebox_override("normal", alternate.get_theme_stylebox("normal") if choosing else primary_style)
	primary.add_theme_color_override("font_color", game.hud.PAPER if choosing else game.hud.INK)
	response.text = ""
	alternate.hide()
	journal.hide()
	modal.show()
	# Keyboard shortcuts are handled centrally. Buttons remain clickable.
	game.paused = true
	game.player.enabled = false
	game.player.velocity = Vector3.ZERO

func _build() -> void:
	modal = Control.new()
	modal.name = "FirstShiftDialogue"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.hud.root.add_child(modal)
	voice = AudioStreamPlayer.new()
	voice.name = "DispatcherVoice"
	voice.bus = "Dialogue"
	voice.volume_db = -5.0
	modal.add_child(voice)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(.014,.032,.036,.87)
	modal.add_child(shade)
	game.hud.panel(modal, Rect2(326,210,788,455), Color("13292c"))
	game.hud.text(modal, "ОСТРОВ СЕВЕРНЫЙ  /  ДЕМОНСТРАЦИЯ", Rect2(368,246,704,26), 14, Color("deb777"))
	heading = game.hud.text(modal, "", Rect2(368,282,704,43), 28)
	dialogue = game.hud.text(modal, "", Rect2(368,346,704,132), 22)
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	response = game.hud.text(modal, "", Rect2(368,478,704,31), 17, Color("deb777"))
	primary = game.hud.make_button(modal, "", Vector2(368,526), accept, true)
	primary_style = primary.get_theme_stylebox("normal")
	alternate = game.hud.make_button(modal, "2 · Северный", Vector2(701,526), func(): choose(false))
	journal = game.hud.make_button(modal, "Открыть журнал · J", Vector2(368,590), read_log)

func hint() -> String:
	if awaiting_contact():
		return "J — сверить позывной  ·  E у домашнего радио — ответить"
	if stage != Stage.WATCH:
		return ""
	if game.campaign.state.night:
		return "F — держать фонарь включённым. Когда шаги стихнут, вернитесь к койке."
	match game.campaign.target_id():
		"fuel": return "WASD — движение  ·  E — забрать канистру  ·  M — карта"
		"beacon": return "E у генератора — запустить маяк. Дверь башни рядом."
		"lighthouse_lens": return "E у двери — войти в маяк. Поднимитесь по лестнице на WASD."
		"workbench": return "Соберите три дерева у валежника. Затем нажмите E у верстака."
		_:
			return "Фонарь горит. E у койки в хижине — начать ночь." if game.player.lantern_on else "Войдите в хижину. F — включить фонарь, E у койки — начать ночь."
