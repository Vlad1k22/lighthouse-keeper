extends RefCounted
## Authored shifts, interactive night scenes and persistent clues.
const DAYS = preload("res://scripts/campaign_days.gd")
const SHORT_DAYS := 14
const LEGACY_DAYS := 30
const SHORT_CLUES: Array[int] = [5, 8, 11]
const LEGACY_CLUES: Array[int] = [9, 17, 26]
const DAY_SECONDS := 50.0
const CODE := "314"
const FIRST_RADIO_AT := 2.0
const FIRST_SHADOW_AT := 5.5
const FIRST_WINDOW_END := 9.5
var game: Node
var enabled := true
var shifts: Array = DAYS.build()
var state: Dictionary
var code_panel: Control
var code_input: LineEdit
var code_feedback: Label
var first_shadow: CharacterBody3D

func setup(owner_game: Node) -> void:
	game = owner_game
	reset()

func reset() -> void:
	select_calendar(SHORT_DAYS)
	state = {"day":1,"marks":{},"completed_days":[],"day_clock":0.0,"night":false,"night_clock":0.0,"safe_clock":0.0,"event_done":false,"cue":0,"blackout":false,"need_radio":false,"beacon_charge":0,"run_seconds":0.0,"clearance":false,"dusk_warned":false}
	state.merge({"first_route":"","first_radio":false})
	first_shadow = null
	if is_instance_valid(code_panel):code_panel.hide()

func select_calendar(days: int) -> void:
	if days==LEGACY_DAYS:
		if calendar_days()!=LEGACY_DAYS:
			shifts = DAYS.build_legacy()
	elif calendar_days()!=SHORT_DAYS:
		shifts = DAYS.build()

func calendar_days() -> int:
	return shifts.size()

func final_night() -> int:
	return calendar_days()-1

func clue_days() -> Array[int]:
	return LEGACY_CLUES if calendar_days()==LEGACY_DAYS else SHORT_CLUES

func ensure_day() -> void:
	if int(state.day)==game.day:return
	state.day = game.day
	state.marks = {}
	for key in ["day_clock","night_clock","safe_clock"]:state[key]=0.0
	for key in ["night","event_done","blackout","need_radio","dusk_warned"]:state[key]=false
	state.cue = 0

func entry() -> Dictionary:
	return shifts[clampi(game.day,1,calendar_days())-1]

func act() -> String:
	var legacy := calendar_days()==LEGACY_DAYS
	if game.day<=(7 if legacy else 4):return "ОБУСТРОЙСТВО"
	if game.day<=(15 if legacy else 8):return "СОМНЕНИЯ"
	if game.day<=(23 if legacy else 12):return "ПАМЯТЬ"
	return "ПУТЬ С ОСТРОВА"

func flag_done(id: String) -> bool:
	match id:
		"fuel":return game.fuel_found
		"beacon":return game.lighthouse_on
		"workbench":return game.barricade_built
		"tools":return game.expedition.state.tools
		"pump":return game.expedition.state.pump
		"battery":return game.expedition.state.battery
		"transmitter":return game.expedition.state.signal
		"ship_hull":return game.expedition.state.hull
		"ship_engine":return game.expedition.state.engine
		"ship_fuel":return game.expedition.state.ship_fuel
		"ship_stores":return game.expedition.state.stores
		"scrap","fire":return game.expedition.state.daily.has(id)
	return false

func goal_done(index: int) -> bool:
	var goal: Dictionary = entry().goals[index]
	return state.marks.has(str(index)) or goal.kind=="base" and flag_done(goal.id)

func next_index() -> int:
	ensure_day()
	for i in entry().goals.size():
		if not goal_done(i):return i
	return -1

func day_complete() -> bool:
	return next_index()<0

func reserves_action(id: String) -> bool:
	if not enabled or state.night:
		return false
	var index := next_index()
	return index>=0 and entry().goals[index].id==id and entry().goals[index].kind!="base"

func observe(id: String, success: bool) -> void:
	if not enabled or not success:return
	ensure_day()
	for i in entry().goals.size():
		var goal: Dictionary = entry().goals[i]
		if goal.id==id and goal.kind=="base":state.marks[str(i)]=true

func resources(values: Dictionary, deduct: bool = false) -> bool:
	if deduct:
		for key in values:
			var available: int = int(game.expedition.state.scrap) if key=="scrap" else int(game.inventory.get(key,0))
			if available<int(values[key]):
				game.notify("Для работы нужно: %s. Дерево — валежник, детали — склад, топливо — гавань." % cost_text(values),8)
				return false
	for key in values:
		var amount: int = int(values[key])*(-1 if deduct else 1)
		match key:
			"scrap":game.expedition.state.scrap+=amount
			"wood","fuel":game.inventory[key]+=amount
			"food":
				for i in amount:game.food_items.append(game.PROVISIONS.ration())
			"fish":
				for i in amount:game.fish_items.append(game.PROVISIONS.fish_item("perch",450))
			"health","hunger","sanity":game.set(key,clampf(float(game.get(key))+amount,0,100))
	game.sync_provisions()
	return true

func cost_text(values: Dictionary) -> String:
	var words := PackedStringArray()
	for key in values:words.append("%d %s" % [values[key],{"wood":"дерева","scrap":"деталей","fuel":"топлива"}.get(key,key)])
	return ", ".join(words)

func complete_goal(index: int) -> void:
	if state.marks.has(str(index)):return
	var goal: Dictionary = entry().goals[index]
	state.marks[str(index)] = true
	resources(goal.reward)
	var id := "c:%d:%d" % [game.day,index]
	if not str(goal.story).is_empty() and id not in game.journal_entries:game.journal_entries.append(id)
	if index==0 and game.day in clue_days() and "c:code" not in game.journal_entries:game.journal_entries.append("c:code")
	game.sound.interact("wood")
	game.interaction_cooldown = .35
	game.notify("%s. %s" % [goal.title,"Задачи выполнены. Подготовьтесь к ночи у хижины." if day_complete() else "Следующая цель отмечена на карте M."],7)
	game.expedition.update_visuals()

func intercept(id: String) -> int:
	# -1: use the original station; 0: blocked; 1: handled here.
	if not enabled:return -1
	ensure_day()
	if state.night:
		if game.day==1:
			if id=="radio":
				if state.night_clock<FIRST_RADIO_AT:
					game.notify("Приёмник пока молчит. Прислушайтесь.", 3)
					return 0
				if not state.first_radio:
					state.first_radio = true
					game.sound.radio_signal()
					game.notify("Сквозь шум слышно: «Красный ящик. Старый склад». Голос почти ваш.", 7)
				return 1
			if id=="beacon" and state.night_clock>=FIRST_SHADOW_AT and game.lighthouse_on and state.first_route!="outside":
				complete_first_watch("outside")
				game.notify("Генератор работает ровно. За хижиной стихли шаги. Вернитесь к койке.", 7)
				return 1
		if id=="beacon" and state.blackout:
			state.blackout = false
			game.lighthouse_on = true
			state.beacon_charge = maxi(1,int(state.beacon_charge))
			game.beacon.set_powered(true)
			state.event_done = not state.need_radio
			game.sound.interact("beacon")
			game.notify("Питание восстановлено. "+("Теперь подтвердите сигнал на домашнем радио." if state.need_radio else "Возвращайтесь к хижине."),8)
			return 1
		if id=="radio" and not state.event_done and entry().night.kind in ["static","false_call","last"]:
			if state.blackout:
				game.notify("Сначала восстановите питание у генератора маяка.")
				return 0
			if requires_radio_verification():
				game.hud.tuner.open_verification()
			else:
				confirm_night_radio()
			return 1
		return -1
	var index := next_index()
	if index<0:return -1
	var goal: Dictionary = entry().goals[index]
	if goal.id!=id or goal.kind=="base":return -1
	if id=="lighthouse_lens" and not game.lighthouse_on:
		return 0
	if goal.kind=="code":
		open_code()
		return 1
	if goal.kind=="service" and not game.expedition.state.tools:
		game.notify("Для этой работы нужны инструменты со склада.")
		return 0
	if not resources(goal.cost,true):return 0
	complete_goal(index)
	return 1

func requires_radio_verification() -> bool:
	return calendar_days()==SHORT_DAYS and game.day in [11,13]

func confirm_night_radio() -> void:
	if not state.night or state.blackout or state.event_done:
		return
	state.need_radio = false
	state.event_done = true
	game.sound.radio_signal()
	if requires_radio_verification() or entry().night.kind=="last":
		game.notify("Настоящий сигнал подтверждён. До утра оставайтесь у света.",8)
	else:
		game.notify("Вы отключили ложную передачу. Дождитесь конца ночной сцены у хижины.",8)

func prep_missing() -> String:
	if not game.barricade_built:return "Укрепите хижину у верстака: 3 дерева."
	if not game.lighthouse_on:return "Включите генератор маяка. Топливо — в гавани."
	if game.hunger<12:return "Съешьте готовую еду клавишей R или наберите воду у насоса."
	if not game.player.lantern_on:return "Включите ручной фонарь клавишей F."
	return ""

func begin_night() -> bool:
	ensure_day()
	if game.day>=calendar_days():
		game.notify("Окно выхода открыто. Подготовьте катер и подойдите к штурвалу.")
		return false
	if not day_complete():
		game.notify("Сначала завершите дневную задачу. Ближайшая цель отмечена на карте M.")
		return false
	var missing := prep_missing()
	if not missing.is_empty():
		game.notify(missing,7)
		return false
	if state.night:return true
	if game.day==1 and game.building_interiors.active!="cabin":
		game.notify("Войдите в хижину по E и подойдите к койке, чтобы начать дежурство.", 7)
		return false
	state.night = true
	state.night_clock = 0.0
	state.safe_clock = 0.0
	state.cue = 0
	state.event_done = false
	state.blackout = entry().night.kind in ["blackout","last"]
	state.need_radio = entry().night.kind=="last"
	if state.blackout:
		game.lighthouse_on = false
		game.beacon.set_powered(false)
	game.hour = 20
	game.spawn_clock = 0
	game.night_spawned = false
	game.notify(entry().night.text,12)
	return true

func advance(delta: float) -> void:
	if not enabled or delta<=0:return
	ensure_day()
	state.run_seconds += delta
	if not state.night:
		state.day_clock += delta
		game.hour = 7+12.5*minf(1,float(state.day_clock)/DAY_SECONDS)
		if state.day_clock>=35 and not state.dusk_warned and game.day<calendar_days():
			state.dusk_warned = true
			game.notify("Скоро ночь. Проверьте задачи, маяк, укрепление и фонарь. У хижины можно приблизить закат.",7)
		if game.day>1 and game.day<calendar_days() and state.day_clock>=DAY_SECONDS and day_complete() and prep_missing().is_empty():begin_night()
		return
	state.night_clock += delta
	var duration: float = entry().night.seconds
	game.hour = 20+3.5*minf(1,float(state.night_clock)/maxf(1,duration))
	if game.day==1:
		advance_first_watch(delta, duration)
		return
	if game.player.lantern_on and game.is_safe(game.player.position):state.safe_clock += delta
	var kind: String = entry().night.kind
	if kind not in ["blackout","last","static","false_call"] and state.safe_clock>=4:state.event_done = true
	if int(state.cue)==0 and state.night_clock>=2:
		state.cue = 1
		game.sound.horror_cue("knock" if kind in ["knocks","siege"] else "whisper",Vector3(2,1.8,4.3))
	elif int(state.cue)==1 and state.night_clock>=7:
		state.cue = 2
		game.sound.horror_cue("radio" if kind in ["static","false_call","last"] else "steps",Vector3(8,1.6,2))
		game.camera_shake = maxf(game.camera_shake,.16 if game.day>7 else .06)
	elif int(state.cue)==2 and state.night_clock>=duration:
		state.cue = 3
		game.notify("Ночная сцена закончилась. [E] у двери — встретить рассвет." if state.event_done else night_instruction(),8)

func complete_first_watch(route: String) -> void:
	state.first_route = route
	state.event_done = true

func first_window_strength() -> float:
	if not enabled or game.day!=1 or not state.night:
		return 0.0
	var time: float = state.night_clock
	return smoothstep(FIRST_SHADOW_AT, FIRST_SHADOW_AT+.55, time) * (1.0-smoothstep(FIRST_WINDOW_END-.85, FIRST_WINDOW_END, time))

func advance_first_watch(delta: float, duration: float) -> void:
	var time: float = state.night_clock
	var in_cabin: bool = game.building_interiors.active=="cabin"
	var in_room: bool = not game.building_interiors.active.is_empty() or game.lighthouse_interior.active
	if int(state.cue)==0 and time>=FIRST_RADIO_AT:
		state.cue = 1
		if not in_room or in_cabin:
			game.sound.horror_cue("radio", game.building_interiors.actions.get("radio", Vector3(8,1.6,2)) + Vector3.UP*.9)
		game.notify("Приёмник зашипел. Подойдите к радио, чтобы разобрать слова.", 6)
	if int(state.cue)==1 and time>=FIRST_SHADOW_AT:
		state.cue = 2
		spawn_first_shadow()
		if not in_room or in_cabin:
			var window: Vector3 = Vector3(-1.87,1.45,-2.22) + game.building_interiors.ROOMS.cabin.origin if in_cabin else Vector3(3.1,1.45,-3.35)
			game.sound.horror_cue("steps", window)
		game.notify(night_instruction(), 7)
	if not state.event_done and time>=FIRST_SHADOW_AT and in_cabin and game.player.lantern_on:
		state.safe_clock += minf(delta,time-FIRST_SHADOW_AT)
		if state.safe_clock>=4.0:
			complete_first_watch("inside")
	if int(state.cue)==2 and time>=duration:
		state.cue = 3
		game.notify("Шаги стихли. "+night_instruction() if state.event_done else night_instruction(), 7)

func spawn_first_shadow() -> void:
	if is_instance_valid(first_shadow) or float(state.night_clock)<FIRST_SHADOW_AT or float(state.night_clock)>=14:
		return
	game.spawn_shadow(Vector3(3.13,1.12,-3.28))
	first_shadow = game.enemies.back()
	first_shadow.passive = true
	first_shadow.stationary = true

func night_instruction() -> String:
	if game.day==1:
		if state.first_route=="outside":
			return "Вернитесь к койке и дождитесь рассвета."
		if state.first_route=="inside":
			return "Можно встретить рассвет у койки или проверить генератор."
		if state.night_clock<FIRST_SHADOW_AT:
			return "Прислушайтесь к радио и посмотрите на окно."
		return "Останьтесь в хижине с фонарём (F) или проверьте генератор."
	if state.blackout:return "Восстановите питание у генератора маяка · E."
	if state.need_radio or entry().night.kind in ["static","false_call"] and not state.event_done:
		return "Домашнее радио · E. Сверьте позывной и отметку в журнале." if requires_radio_verification() else "Домашнее радио у западной стены хижины · E."
	return "Фонарь F включён; побудьте в безопасном освещённом месте."

func request_rest() -> bool:
	ensure_day()
	if not game.is_night():return begin_night()
	if game.day==1 and game.building_interiors.active!="cabin":
		game.notify("Рассвет встречают у койки в хижине. Вход — E у двери.", 7)
		return false
	# Editor/demo scripts may freeze the clock and set 22:00 directly. Normal play enters via begin_night.
	var forced_preview: bool = not state.night and game.hours_per_second==0
	if not forced_preview:
		if not state.night:return begin_night()
		if state.night_clock<float(entry().night.seconds) or not state.event_done:
			game.notify("Ночное дежурство: %d сек. %s" % [maxi(0,ceili(float(entry().night.seconds)-float(state.night_clock))),night_instruction()],7)
			return false
		var missing := prep_missing()
		if not missing.is_empty():
			game.notify(missing)
			return false
	if game.day>=calendar_days():
		game.notify("Окно выхода открыто. Подготовьте катер и подойдите к штурвалу.")
		return false
	finish_night()
	return true

func finish_night() -> void:
	if game.day==1 and game.first_shift_demo.active():
		game.first_shift_demo.start_contact()
		return
	var completed: int = game.day
	if completed not in state.completed_days:
		state.completed_days.append(completed)
		resources(entry().reward)
		var journal_id := "n:%d" % completed
		if journal_id not in game.journal_entries:game.journal_entries.append(journal_id)
	if completed==final_night():state.clearance = true
	state.beacon_charge = maxi(0,int(state.beacon_charge)-1)
	game.day = mini(calendar_days(),game.day+1)
	game.hour = 7
	game.health = minf(100,game.health+5)
	game.hunger = maxf(0,game.hunger-8)
	game.sanity = minf(100,game.sanity+7)
	game.expedition.dawn()
	ensure_day()
	game.clear_enemies()
	game.notify("День %d · %s. %s" % [game.day,entry().title,entry().brief],11)
	game.save_checkpoint()

func spawn_threats() -> void:
	if game.day==1:
		spawn_first_shadow()
		return
	var kind: String = entry().night.kind
	var count: int = 3 if kind=="siege" else (2 if game.day>=10 else 1)
	var passive: bool = game.day<=3 or kind in ["watcher","double","silence"]
	var points := [Vector3(-6,1.3,5),Vector3(12,1.3,-6),Vector3(-2,1.3,12)]
	for i in count:
		var appearance := "keeper" if kind == "double" and i == 0 else "drowned" if i == 0 and kind in ["storm","siege"] else "shadow"
		game.spawn_shadow(points[i], appearance)
		game.enemies.back().passive = passive
		game.enemies.back().stationary = kind=="watcher"
		if kind=="double" and i==0:
			game.enemies.back().mirroring = true

func target_id() -> String:
	if not enabled:return ""
	if game.first_shift_demo.awaiting_contact():return "radio"
	ensure_day()
	if state.night:
		if game.day==1 and state.night_clock>=FIRST_RADIO_AT and state.night_clock<FIRST_SHADOW_AT and not state.first_radio:
			return "radio"
		if state.blackout:return "beacon"
		if not state.event_done and (state.need_radio or entry().night.kind in ["static","false_call"]):return "radio"
		return "shelter"
	var index := next_index()
	if index>=0:return entry().goals[index].id
	if game.day==calendar_days():return "ship_helm"
	if not game.barricade_built:return "workbench"
	if not game.lighthouse_on:return "beacon"
	return "shelter"

func prompt(id: String, original: String) -> String:
	if not enabled:return original
	if game.first_shift_demo.awaiting_contact() and id=="radio":
		return "Ответить береговой станции"
	if game.day==1 and id=="shelter" and state.night:
		return "Встретить рассвет" if state.event_done and state.night_clock>=entry().night.seconds else "Проверить, сколько осталось до рассвета"
	if id=="shelter" and game.day<calendar_days():return "Закончить ночное дежурство" if state.night else "Подготовиться и приблизить ночь"
	if game.day==1 and state.night and id=="radio":
		return "Разобрать помехи" if not state.first_radio else "Вспомнить услышанное"
	if state.night and id==target_id():return night_instruction().trim_suffix(" · E.")
	var index := next_index()
	if index>=0 and entry().goals[index].id==id:return entry().goals[index].title
	return original

func tasks() -> String:
	if game.first_shift_demo.awaiting_contact():
		return "ДЕМО · ПЕРВАЯ СМЕНА\nРАССВЕТ\n\n✓ Маяк работает\n✓ Дежурство завершено\n○ Ответить береговой станции\n\nJ — журнал · M — карта"
	var lines := "ДЕМО · ПЕРВАЯ СМЕНА\nОБУСТРОЙСТВО\n" if game.first_shift_demo.active() else "ДЕНЬ %02d / %d · %s\n%s\n" % [game.day,calendar_days(),entry().title,act()]
	if state.night:
		var guidance := "E у хижины — рассвет" if state.event_done else "Не уходите от света"
		if game.day==1:
			guidance = "E у койки — рассвет" if state.event_done and state.night_clock>=entry().night.seconds else ""
		return lines+"\nНОЧНОЕ ДЕЖУРСТВО · %d сек\n%s\n\n%s\nM — карта · J — записи" % [maxi(0,ceili(float(entry().night.seconds)-float(state.night_clock))),"✓ Событие пройдено" if state.event_done else "○ "+night_instruction(),guidance]
	for i in entry().goals.size():lines += "\n%s %s" % ["✓" if goal_done(i) else "○",entry().goals[i].title]
	return lines+"\n\n%s Маяк  ·  %s Хижина\n%s Фонарь  ·  R — еда\nM — карта · J — записи" % ["✓" if game.lighthouse_on else "○","✓" if game.barricade_built else "○","✓" if game.player.lantern_on else "○"]

func board_summary(ship_checks: String) -> String:
	if game.first_shift_demo.active():
		return tasks()+"\n\n"+game.first_shift_demo.hint()+"\n\nM / Esc — вернуться"
	var content := "ДЕНЬ %02d / %d · %s\n%s\n\n" % [game.day,calendar_days(),entry().title,act()]
	for i in entry().goals.size():content+="%s %s\n" % ["✓" if goal_done(i) else "○",entry().goals[i].title]
	content+="\n%s Маяк · %s Хижина · %s Фонарь\n" % ["✓" if game.lighthouse_on else "○","✓" if game.barricade_built else "○","✓" if game.player.lantern_on else "○"]
	if state.night:content+="Ночь: "+night_instruction()+"\n"
	else:content+=entry().brief+"\n"
	content+="\nКАТЕР «СЕВЕРНЫЙ»\n"+ship_checks+"Выход: утром %d-го дня после кода и ночи %d.\n" % [calendar_days(),final_night()]
	content+="\nДетали %d · Дерево %d · Топливо %d\nГенератор: запас на %d ночи.\nE у хижины — ночь / рассвет. J — записи.\nM / Esc — вернуться" % [int(game.expedition.state.scrap),game.inventory.wood,game.inventory.fuel,int(state.beacon_charge)]
	return content

func journal_entry(id: String) -> Dictionary:
	if id=="c:code":
		var values := PackedStringArray()
		var days := clue_days()
		for i in days.size():
			values.append(CODE.substr(i,1) if "c:%d:0" % days[i] in game.journal_entries else "?")
		var directions := "Первая цифра — запись дня %d.\nВторая — памятка под насосом, день %d.\nТретья — отметка в лодке, день %d.\n\nПередайте пакет на передатчике в день %d." % [days[0],days[1],days[2],final_night()]
		return {"title":"Контрольная группа","text":"Номер пакета связи: "+" · ".join(values)+"\n\n"+directions+" Настоящий позывной — «Берег-четыре». Ночной голос без подтверждения не является командой к выходу."}
	var bits := id.split(":")
	if bits.size()<2 or not bits[1].is_valid_int():return {}
	var day: int = int(bits[1])
	if day<1 or day>calendar_days():return {}
	var record: Dictionary = shifts[day-1]
	if id=="n:1":
		var response: String = {"inside":"Я переждал шаги у света в хижине.","outside":"Я вышел проверить генератор. Он работал, хотя шаги были совсем рядом."}.get(state.first_route, "Я записал время, когда шаги стихли.")
		var clue := "По радио прозвучало: «Красный ящик. Старый склад»." if state.first_radio else "Утром под журналом нашлась записка: «Красный ящик. Старый склад»."
		return {"title":"Ночь 01 · Красный ящик","text":record.night.text+"\n\n"+response+" "+clue+" В ящике должны быть инструменты прежнего смотрителя."}
	if bits[0]=="n":return {"title":"Ночь %02d · %s" % [day,record.title],"text":record.night.text+"\n\nДежурство окончено. Время и порядок событий записаны, чтобы сверить их утром."}
	if bits[0]=="c" and bits.size()==3 and bits[2].is_valid_int():
		var index: int = int(bits[2])
		if index>=0 and index<record.goals.size():return {"title":"День %02d · %s" % [day,record.title],"text":record.goals[index].story}
	return {}

func restore(saved: Dictionary, legacy: bool = false) -> void:
	if not legacy:enabled = bool(saved.get("enabled",true))
	for key in state:
		if saved.has(key) and typeof(saved[key])==typeof(state[key]):state[key]=saved[key]
	for key in ["day","beacon_charge","cue"]:state[key]=int(saved.get(key,state[key]))
	for key in ["day_clock","night_clock","safe_clock","run_seconds"]:state[key]=maxf(0,float(saved.get(key,state[key])))
	state.completed_days = state.completed_days.map(func(day):return int(day))
	if legacy:
		state.day = game.day
		state.beacon_charge = 2 if game.lighthouse_on else 0
		state.completed_days = range(1,clampi(game.day,1,calendar_days()))
		state.clearance = game.day>=calendar_days()
		state.day_clock = clampf((game.hour-7)/12.5,0,1)*DAY_SECONDS
		var imported_night: bool = game.is_night() and game.day<calendar_days()
		if imported_night:
			state.night = true
			for i in entry().goals.size():state.marks[str(i)]=true
			state.blackout = entry().night.kind in ["blackout","last"]
			state.need_radio = entry().night.kind=="last"
			if state.blackout:game.lighthouse_on=false
		for clue_day in clue_days():
			if game.day>clue_day or imported_night and game.day==clue_day:
				var clue_id := "c:%d:0" % clue_day
				if clue_id not in game.journal_entries:game.journal_entries.append(clue_id)
				if "c:code" not in game.journal_entries:game.journal_entries.append("c:code")
	if game.day==1 and not saved.has("first_route"):
		state.marks.erase("1")
		if state.night:
			state.marks["2"] = true
			if state.event_done:
				state.first_route = "inside"
	ensure_day()

func serialize() -> Dictionary:
	var result := state.duplicate(true)
	result.enabled = enabled
	return result

func open_code() -> void:
	if not is_instance_valid(code_panel):
		code_panel = Control.new()
		code_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		game.hud.root.add_child(code_panel)
		var shade := ColorRect.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(.01,.025,.03,.93)
		code_panel.add_child(shade)
		game.hud.panel(code_panel,Rect2(370,230,700,430),Color("172b2b"))
		game.hud.text(code_panel,"КОНТРОЛЬНАЯ ГРУППА",Rect2(410,265,610,40),28)
		var hint = game.hud.text(code_panel,"",Rect2(410,325,610,65),19)
		hint.name = "ClueDays"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		code_input = LineEdit.new()
		code_input.position = Vector2(410,420)
		code_input.size = Vector2(250,60)
		code_input.max_length = 3
		code_input.placeholder_text = "___"
		code_input.add_theme_font_size_override("font_size",32)
		code_input.text_submitted.connect(func(_value):submit_code(code_input.text))
		code_panel.add_child(code_input)
		game.hud.make_button(code_panel,"Передать пакет",Vector2(690,424),func():submit_code(code_input.text),true)
		code_feedback = game.hud.text(code_panel,"",Rect2(410,510,610,70),19)
		code_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.paused = true
	game.player.enabled = false
	game.player.velocity = Vector3.ZERO
	code_feedback.text = ""
	var days := clue_days()
	code_panel.get_node("ClueDays").text = "Три цифры из записей дней %d, %d и %d.\nEsc — вернуться на остров; затем J — журнал." % [days[0],days[1],days[2]]
	code_input.text = ""
	code_panel.show()
	code_input.grab_focus()

func submit_code(value: String) -> bool:
	if not enabled or game.day!=final_night() or next_index()!=0:return false
	if value!=CODE:
		if is_instance_valid(code_feedback):code_feedback.text = "Пакет отклонён. Сверьте три записи в журнале. Ресурсы не расходуются."
		return false
	complete_goal(0)
	close_code()
	return true

func close_code() -> void:
	if is_instance_valid(code_panel):code_panel.hide()
	game.paused = false
	game.player.enabled = game.playing and not game.finished and not game.fishing.is_open()
	game.interaction_cooldown = .35

func code_open() -> bool:
	return is_instance_valid(code_panel) and code_panel.visible
