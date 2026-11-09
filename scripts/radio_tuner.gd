extends Control
## Optional stations and late-night verification share the receiver.
const LOG := "radio:watch"
const CREW := "radio:crew"
const CHECK_11 := "radio:check11"
const CHECK_13 := "radio:check13"
const ARCHIVE := {
	LOG: {"title":"Эфир 97,8 · запись прежней смены","text":"Вчерашний смотритель диктует время: 02:16. Через секунду звучит ваш голос, хотя микрофон выключен. Запись обрывается на словах: «Следы у валежника опять мои»."},
	CREW: {"title":"Эфир 102,3 · журнал экипажа","text":"«Если выберешься к катеру, загляни под койку в каюте “Северного”. Мы оставили там страницу с подписями. Её легко пропустить в темноте»."},
	CHECK_11: {"title":"Контрольная отметка · ночь 11","text":"Протокол берега на эту ночь.\n\nПозывной «Берег-четыре»\nКонтрольная отметка 22:10\n\nГолос, который торопит выйти, может знать позывной. Сверьте и отметку."},
	CHECK_13: {"title":"Контрольная отметка · ночь 13","text":"Последняя проверка перед рассветом.\n\nПозывной «Берег-четыре»\nКонтрольная отметка 23:40\n\nПосле запуска генератора подтвердите обе строки на домашнем радио."},
}
var game: Node
var hud: CanvasLayer
var verifying := false
var dial: HSlider
var frequency: Label
var title: Label
var body: Label
var message: Label
var listen_button: Button
var choices: Array[Button] = []
var log_button: Button
var candidates: Array[Dictionary] = []
var expected_time := ""
var log_id := ""

func setup(owner: CanvasLayer) -> void:
	hud = owner
	game = hud.game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.015,.031,.037,.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	hud.panel(self,Rect2(300,149,840,602),Color("12282f"))
	hud.text(self,"БЕРЕГОВАЯ СВЯЗЬ   /   ПРИЁМНИК",Rect2(353,181,732,27),14,hud.GOLD)
	title = hud.text(self,"",Rect2(353,222,732,45),28)
	body = hud.text(self,"",Rect2(353,281,732,72),17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frequency = hud.text(self,"",Rect2(353,367,732,36),23,hud.GOLD)
	dial = HSlider.new()
	dial.min_value = 970
	dial.max_value = 1054
	dial.step = 1
	dial.value = 1046
	dial.position = Vector2(353,416)
	dial.size = Vector2(729,28)
	dial.value_changed.connect(func(_value): _refresh_dial())
	add_child(dial)
	listen_button = hud.make_button(self,"Прослушать · E",Vector2(353,473),listen,true)
	for i in 3:
		var button: Button = hud.make_button(self,"",Vector2(353,372+i*60),func(): verify(i))
		button.size.x = 700
		choices.append(button)
	message = hud.text(self,"",Rect2(353,558,732,95),16,hud.GOLD)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_button = hud.make_button(self,"Сверить журнал · J",Vector2(353,672),read_log)
	hud.make_button(self,"Закрыть · Esc",Vector2(684,672),close)
	hide()

func nearby() -> bool:
	return game.near_station("radio")!=null or (game.expedition.state.signal and game.near_station("transmitter")!=null)

func open_scan() -> void:
	if not nearby() or game.player.jump_in_progress:
		game.notify("Настройка частоты доступна у домашнего радио или работающего передатчика.")
		return
	_open(false)
	title.text = "Поиск частоты"
	body.text = "← и → двигают шкалу на 0,1. E — прослушать. Карандашные отметки: 97,8 · 102,3 · 104,6."
	_refresh_dial()
	dial.grab_focus()

func _refresh_dial() -> void:
	var value := int(dial.value)
	frequency.text = "%d,%d МГц" % [floori(value/10.0), value%10]

func listen() -> void:
	if not visible or verifying:return
	game.sound.radio_signal()
	match int(dial.value):
		978:
			_receive(LOG,5)
		1023:
			_receive(CREW,8)
		1046:
			message.text = "«Берег-четыре». Служебная частота. Ждите вызова по расписанию и сверяйте его контрольные отметки."
		_:
			message.text = "Слышен только шум. Ищите частоту по отметкам на шкале."

func _receive(id: String, day: int) -> void:
	if game.day<day:
		message.text = "На этой частоте пока тишина. Проверьте её в одну из следующих смен."
		return
	if id not in game.journal_entries:
		game.journal_entries.append(id)
	message.text = ARCHIVE[id].title+" · Запись добавлена в журнал J."
	log_id = id
	log_button.show()

func open_verification() -> void:
	_open(true)
	log_id = CHECK_13 if game.day==13 else CHECK_11
	if log_id not in game.journal_entries:
		game.journal_entries.append(log_id)
	expected_time = "23:40" if game.day==13 else "22:10"
	var incorrect := "23:10" if game.day==13 else "21:50"
	candidates = [
		{"call":"Северный","time":expected_time},
		{"call":"Берег-четыре","time":expected_time},
		{"call":"Берег-четыре","time":incorrect},
	]
	if game.day==13:candidates.push_front(candidates.pop_back())
	title.text = "Перехваченные передачи · 104,6 МГц"
	body.text = "Выберите подтверждённую передачу. Позывной и контрольная отметка лежат в журнале J."
	for i in choices.size():
		var row: Dictionary = candidates[i]
		choices[i].text = "%d · %s   /   %s" % [i+1,row.call,row.time]
	game.sound.radio_signal()

func verify(index: int) -> void:
	if not visible or not verifying or index<0 or index>=candidates.size():
		return
	var row: Dictionary = candidates[index]
	if row.call!="Берег-четыре" or row.time!=expected_time:
		message.text = "Контрольные данные расходятся. Откройте журнал и проверьте обе строки."
		game.sound.radio_signal()
		return
	close()
	game.campaign.confirm_night_radio()

func _open(verify_mode: bool) -> void:
	verifying = verify_mode
	log_id = ""
	dial.visible = not verifying
	frequency.visible = not verifying
	listen_button.visible = not verifying
	for button in choices:button.visible = verifying
	log_button.visible = verifying
	message.text = ""
	game.extras.stop_record()
	game.paused = true
	game.player.enabled = false
	show()

func read_log() -> void:
	var id := log_id
	close()
	if id in game.journal_entries:
		game.open_journal_entry(id)
	else:
		game.open_journal()

func handle(key: Key) -> void:
	match key:
		KEY_ESCAPE,KEY_U:close()
		KEY_J:read_log()
		KEY_E:listen()
		KEY_LEFT:
			if not verifying:dial.value -= 1
		KEY_RIGHT:
			if not verifying:dial.value += 1
		KEY_1,KEY_KP_1:verify(0)
		KEY_2,KEY_KP_2:verify(1)
		KEY_3,KEY_KP_3:verify(2)

func close() -> void:
	hide()
	game.paused = false
	game.player.enabled = game.playing and not game.finished
