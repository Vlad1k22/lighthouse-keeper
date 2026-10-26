extends RefCounted
## Persistent 30-day survival calendar and the seven-stage escape route.
var game: Node
var state: Dictionary
var board: Control
var board_text: Label
var sailing := false
var sailing_clock := 0.0
const MAP = preload("res://scripts/island_map.gd")
const IDS := ["board","tools","scrap","medical","pump","transmitter","battery","depot","cache","trap","fire","ship_hull","ship_engine","ship_fuel","ship_stores","ship_helm","north_wood"]
const TITLES := ["Первый свет", "Северный склад", "Чистая вода", "Сигнал с острова", "Пробоина", "Сердце катера", "Запас на переход"]

func setup(owner_game: Node) -> void:
	game = owner_game
	reset()

func reset() -> void:
	sailing = false
	sailing_clock = 0
	state = {"scrap":0,"tools":false,"battery":false,"pump":false,"signal":false,"hull":false,"engine":false,"ship_fuel":false,"stores":false,"cache":false,"trap_day":0,"fire_day":0,"last_dawn":1,"visits":{},"daily":{}}
	if is_instance_valid(board):
		board.hide()

func tell(content: String) -> bool:
	game.notify(content,7)
	return false

func require_day(number: int) -> bool:
	if game.day < number:
		return tell("Эта работа появится в плане дня %d. Сейчас: %s. M — карта и план." % [number,title()])
	return true

func used(id: String) -> bool:
	return int(state.visits.get(id,0)) == game.day

func mark(id: String) -> void:
	state.visits[id] = game.day
	state.daily[id] = true

func emergency_stock(id: String) -> bool:
	# Old month-long saves may reach the final day with prototype repairs still unfinished.
	if not game.campaign.enabled or game.day!=30:return false
	if id=="depot":return not state.ship_fuel and game.inventory.fuel<3
	if id=="scrap":
		var needed: int = (0 if state.signal else 2)+(0 if state.hull else 2)+(0 if state.engine else 4)
		return int(state.scrap)<needed
	return false

func cost(timber: int, parts: int) -> bool:
	if game.inventory.wood < timber or int(state.scrap) < parts:
		return tell("Нужно %d древесины и %d деталей. Сейчас: %d и %d. Склад и валежник отмечены на карте M." % [timber,parts,game.inventory.wood,int(state.scrap)])
	game.inventory.wood -= timber
	state.scrap -= parts
	return true

func interact(id: String) -> bool:
	match id:
		"board":
			open_board()
			return true
		"tools":
			if not require_day(2): return false
			if state.tools: return tell("Инструменты уже в рюкзаке. Можно ремонтировать оборудование.")
			state.tools = true
			game.world.get_node("NorthernCoast").find_child("RedToolbox",true,false).hide()
			game.notify("Найден набор инструментов. Насос, передатчик и двигатель теперь можно ремонтировать.",8)
		"scrap":
			if used(id) and not emergency_stock(id): return tell("Сегодня склад уже осмотрен. Завтра можно разобрать следующую секцию.")
			state.scrap += 2
			mark(id)
			game.notify("Разобраны старые механизмы. Детали +2. Запас деталей: %d." % int(state.scrap))
		"north_wood":
			if used(id): return tell("Сегодня валежник собран. Возвращайтесь завтра.")
			game.inventory.wood += 2
			mark(id)
			game.notify("Северный валежник: +2 древесины.")
		"depot":
			if used(id) and not emergency_stock(id): return tell("Две канистры в день. Следующая порция топлива отстоится завтра.")
			game.inventory.fuel += 2
			mark(id)
			game.notify("Из бочки слито топливо +2. Нужно маяку и катеру.")
		"medical":
			if used(id): return tell("Сегодня вы уже использовали аптечку.")
			if game.health >= 100: return tell("Здоровье полное. Сохраните перевязочные материалы на потом.")
			game.health = minf(100,game.health+25)
			mark(id)
			game.notify("Раны обработаны. Здоровье +25. Аптечка доступна раз в день.")
		"pump":
			if not require_day(3): return false
			if not state.pump:
				if not state.tools: return tell("Нужны инструменты со склада на северо-востоке.")
				if not cost(1,2): return false
				state.pump = true
				game.notify("Насос восстановлен. Чистая вода доступна каждый день.")
			else:
				if used(id): return tell("Сегодня запас воды уже пополнен.")
				game.hunger = minf(100,game.hunger+12)
				game.sanity = minf(100,game.sanity+10)
				mark(id)
				game.notify("Вы набрали чистой воды: +12 сытости, +10 рассудка.")
		"battery":
			if not require_day(4): return false
			if state.battery: return tell("Аккумулятор из лодки уже забран.")
			state.battery = true
			game.world.get_node("NorthernCoast").find_child("SalvageBattery",true,false).hide()
			game.notify("Найден аккумулятор передатчика. Под ним записка: «Этот катер ты уже чинил».",10)
		"transmitter":
			if not require_day(4): return false
			if state.signal: return tell("Ответ спасателей: настоящее окно выхода — утром 30-го дня. Выполняйте план и проверяйте записи J." if game.campaign.enabled else "Ответ спасателей: окно спокойного моря с 7-го дня. Подготовьте катер и выходите при дневном свете.")
			if not state.tools or not state.battery: return tell("Нужны инструменты и аккумулятор из остова лодки на северо-восточном берегу.")
			if not cost(0,2): return false
			state.signal = true
			game.sound.radio_signal()
			game.notify("Передатчик работает! «Штормовая полоса закроет выход до 30-го дня. Готовьте катер и ждите контрольную группу». M — план." if game.campaign.enabled else "Передатчик работает! «Вас слышим. С 7-го дня ждём катер у внешнего буя. Запасите еду и топливо». M — план.",10)
		"ship_hull":
			if not require_day(5): return false
			if state.hull: return tell("Пробоина заделана. Корпус готов к переходу.")
			if not state.tools: return tell("Сначала заберите инструменты на складе.")
			if not cost(5,2): return false
			state.hull = true
			game.notify("Корпус катера отремонтирован. Новые доски закрыли пробоину.")
		"ship_engine":
			if not require_day(6): return false
			if state.engine: return tell("Двигатель исправен. Осталось заправить бак и погрузить еду.")
			if not state.tools: return tell("Для ремонта двигателя нужны инструменты со склада.")
			if not cost(0,4): return false
			state.engine = true
			game.sound.interact("beacon")
			game.notify("Заменены фильтр и привод двигателя. Катер снова заводится.")
		"ship_fuel":
			if state.ship_fuel: return tell("Бак уже заправлен.")
			if game.inventory.fuel < 3: return tell("Для перехода нужно 3 канистры. В гавани можно набирать по две в день.")
			game.inventory.fuel -= 3
			state.ship_fuel = true
			game.notify("Бак катера заправлен. Три канистры израсходованы.")
		"ship_stores":
			if not require_day(7): return false
			if state.stores: return tell("Провизия на борту. Три блюда отложены на переход.")
			if game.food_items.size()<3: return tell("Приготовьте 3 блюда на печи. Подойдут рыба и сухпайки. Сырая рыба не подходит.")
			for i in 3: game.food_items.pop_back()
			game.sync_provisions()
			state.stores = true
			game.notify("Три готовых блюда погружены в грузовой ящик катера.")
		"ship_helm":
			if not ready_to_sail(): return tell("Выход утром 30-го дня, после контрольной группы и последнего дежурства. Нужны исправный катер, 3 топлива и 3 готовых блюда. M — план." if game.campaign.enabled else "Катер ещё не готов. Нужны: сигнал спасателям, корпус, двигатель, топливо, 3 блюда и день 7+. M — состояние катера.")
			if game.is_night(): return tell("Выходить в море ночью слишком опасно. Возвращайтесь к штурвалу днём.")
			sailing = true
			sailing_clock = 0
			game.player.enabled = false
			game.player.velocity = Vector3.ZERO
			game.notify("Швартовы отданы. Катер «Северный» берёт курс на материк…",8)
			var coast: Node3D = game.world.get_node("NorthernCoast")
			coast.get_node("CoastalVessel/SailingWake").emitting = true
			coast.get_node("ShipGangplank").hide()
			for child in coast.get_children():
				if str(child.name).begins_with("MooringRope"): child.hide()
				if child is Area3D and child.station_id.begins_with("ship_"): child.hide()
			update_visuals()
			return true
		"cache":
			if state.cache: return tell("В тайнике пусто. Сухпайки уже забраны.")
			state.cache = true
			game.food_items.append(game.PROVISIONS.ration())
			game.food_items.append(game.PROVISIONS.ration())
			game.sync_provisions()
			game.notify("Найдены два сухпайка. Их можно съесть или оставить для катера.")
		"trap":
			if int(state.trap_day)>0:
				if game.day<=int(state.trap_day): return tell("Ловушка поставлена. Улов можно забрать на следующий день.")
				for i in 2: game.fish_items.append(game.PROVISIONS.fish_item("perch",350+i*150))
				game.sync_provisions()
				state.trap_day = 0
				mark(id)
				game.notify("Ловушка принесла две рыбы. Для следующего заброса нужна новая наживка.")
			else:
				if game.fish_items.is_empty(): return tell("Нужна одна сырая рыба для наживки. Поймайте её на старом причале.")
				game.fish_items.remove_at(game.selected_fish)
				game.sync_provisions()
				state.trap_day = game.day
				game.notify("Рыба использована как наживка. Проверьте ловушку завтра.")
		"fire":
			if int(state.fire_day)>0 and int(state.fire_day)>=int(state.last_dawn): return tell("Костёр уже заправлен до следующего утра. В его свете безопаснее.")
			if not cost(1,0): return false
			state.fire_day = game.day
			mark(id)
			game.sanity = minf(100,game.sanity+8)
			game.notify("Костёр в гавани зажжён до утра. Тени боятся его света.")
		_:
			return false
	game.sound.interact("wood")
	game.interaction_cooldown = 0.35
	update_visuals()
	return true

func ready_to_sail() -> bool:
	var ship_ready: bool = state.signal and state.hull and state.engine and state.ship_fuel and state.stores
	if game.campaign.enabled:
		return game.day==30 and game.campaign.state.clearance and game.campaign.state.completed_days.size()>=29 and ship_ready
	return game.day>=7 and ship_ready

func dawn() -> void:
	if int(state.last_dawn)>=game.day: return
	state.last_dawn = game.day
	state.daily = {}
	state.fire_day = 0
	game.was_night = false
	game.clear_enemies()
	game.night_spawned = false
	game.lighthouse_on = false
	game.beacon.set_powered(false)
	for station in game.stations:
		if station.station_id=="wood": station.remaining = 9
	game.sanity = minf(100,game.sanity+12)
	update_visuals()
	if game.day>30:
		game.finish_shift(false)
		game.hud.menu_subtitle.text = "Прошло 30 дней. Последнее окно для выхода\nв море закрыто. Попробуйте подготовить катер раньше."
	else:
		game.notify("День %d: %s. Маяк нужно заправить заново. M — карта и план дня." % [game.day,title()],10)

func sleep() -> bool:
	if game.campaign.enabled:return game.campaign.request_rest()
	if not game.is_night(): return tell("Переждать ночь можно с 20:00 до 06:00. Днём исследуйте остров. M — план.")
	if not game.lighthouse_on or not game.barricade_built: return tell("Для сна нужны работающий маяк и укреплённая хижина.")
	if game.hour>=20: game.day += 1
	game.hour = 7
	game.hunger = maxf(0,game.hunger-18)
	game.health = minf(100,game.health+10)
	dawn()
	return true

func title() -> String:
	if game.campaign.enabled:return game.campaign.entry().title
	return TITLES[game.day-1] if game.day<=7 else ["Запас древесины","Проверка ловушки","Вода и припасы","Огонь в гавани"][(game.day-8)%4]

func objective() -> String:
	if game.campaign.enabled:return game.campaign.entry().brief
	match game.day:
		1: return "Зажгите маяк, укрепите хижину и переживите ночь."
		2: return "Исследуйте север. Заберите инструменты и детали на складе."
		3: return "Почините насос у колодца: инструменты, 1 дерево, 2 детали."
		4: return "Найдите аккумулятор в остове лодки. Передатчику нужны 2 детали."
		5: return "Поднимитесь на катер. Корпусу нужны 5 дерева и 2 детали."
		6: return "Почините двигатель катера: инструменты и 4 детали."
		7: return "Погрузите 3 блюда, заправьте катер и выйдите к спасателям."
	return ["Пополните запас древесины у северного валежника. Готовьте катер к выходу до дня 30.","Проверьте ловушку в гавани. Для наживки нужна сырая рыба; улов — на следующий день.","Пополните запас воды у починенного колодца. Приготовьте еду на завтра.","Разожгите костёр в гавани: 1 дерево. Его свет отгоняет тени до утра."][(game.day-8)%4]

func day_complete() -> bool:
	if game.campaign.enabled:return game.campaign.day_complete()
	match game.day:
		1: return game.barricade_built and game.fuel_found
		2: return state.tools
		3: return state.pump
		4: return state.signal
		5: return state.hull
		6: return state.engine
		7: return ready_to_sail()
	match (game.day-8)%4:
		0: return state.daily.has("north_wood")
		1: return state.daily.has("trap")
		2: return state.daily.has("pump")
		_: return state.daily.has("fire")

func tasks() -> String:
	if game.campaign.enabled:return game.campaign.tasks()
	return "ДЕНЬ %d / 30 · %s\n\n%s План дня\n%s Маяк заправлен\n\n%s\nM — карта и подробности" % [game.day,title(),"✓" if day_complete() else "○","✓" if game.lighthouse_on else "○",objective()]

func update_visuals() -> void:
	var coast: Node3D = game.world.get_node("NorthernCoast")
	var fire_active := int(state.fire_day)>0 and int(state.fire_day)>=int(state.last_dawn)
	coast.get_node("HarborFire").light_energy = 2.2 if fire_active else 0.0
	coast.get_node("HarborEmbers").emitting = fire_active
	coast.get_node("CoastalVessel/NavigationLight").light_energy = 1.4 if state.engine else 0.0
	coast.get_node("CoastalVessel/EngineSmoke").emitting = state.engine
	coast.find_child("RedToolbox",true,false).visible = not state.tools
	coast.find_child("SalvageBattery",true,false).visible = not state.battery
	var patch: MeshInstance3D = coast.find_child("HullPatch",true,false)
	patch.visible = state.hull
	coast.find_child("HullDamage",true,false).visible = not state.hull
	var hatch: MeshInstance3D = coast.find_child("EngineHatch",true,false)
	hatch.material_override = preload("res://scripts/natural_geometry.gd").surface(Color("727966") if state.engine else Color("434c4d"),6)
	preload("res://scripts/ship_visual.gd").sync(coast.get_node("CoastalVessel"),state.hull,state.engine,sailing)
	preload("res://scripts/radio_visual.gd").sync(coast,state.signal)
	var completed := {"tools":state.tools,"battery":state.battery,"pump":state.pump,"transmitter":state.signal,"ship_hull":state.hull,"ship_engine":state.engine,"ship_fuel":state.ship_fuel,"ship_stores":state.stores,"cache":state.cache}
	var names := {"tools":"Инструменты уже в рюкзаке","battery":"Аккумулятор уже забран","pump":"Колодец · набрать чистой воды","transmitter":"Передатчик · ответ спасателей","ship_hull":"Корпус катера отремонтирован","ship_engine":"Двигатель катера исправен","ship_fuel":"Бак катера заправлен","ship_stores":"Провизия погружена","cache":"Тайник · всё забрано"}
	for item in game.stations:
		if not item.station_id in IDS: continue
		if not item.has_meta("original_title"): item.set_meta("original_title",item.display_name)
		var done := bool(completed.get(item.station_id,false))
		item.display_name = names[item.station_id] if done else item.get_meta("original_title")
		item.get_node("InteractionMarker").modulate = Color("89ab95") if done or used(item.station_id) else Color("d2b57c")

func advance(delta: float) -> void:
	if not sailing: return
	var step := minf(delta,7.0-sailing_clock)
	sailing_clock += step
	game.world.get_node("NorthernCoast/CoastalVessel").position.z -= step*3
	game.player.position.z -= step*3
	game.camera_shake = 0.08
	if sailing_clock>=7:
		sailing = false
		game.finish_shift(true)

func reset_ship() -> void:
	var coast: Node3D = game.world.get_node("NorthernCoast")
	coast.get_node("CoastalVessel").position = Vector3(-33,0,-24)
	coast.get_node("CoastalVessel/SailingWake").emitting = false
	coast.get_node("ShipGangplank").show()
	for child in coast.get_children():
		if str(child.name).begins_with("MooringRope"): child.show()
		if child is Area3D and child.station_id.begins_with("ship_"): child.show()

func restore(saved: Dictionary) -> void:
	for key in state.keys():
		if saved.has(key) and typeof(saved[key])==typeof(state[key]): state[key]=saved[key]
	# JSON stores all numbers as floats.
	for key in ["scrap","trap_day","fire_day","last_dawn"]:
		state[key]=maxi(0,int(saved.get(key,state[key])))
	for key in state.visits.keys():
		state.visits[key] = int(state.visits[key])
	update_visuals()

func open_board() -> void:
	if game.fishing.is_open(): return
	if not is_instance_valid(board): build_board()
	game.paused = true
	game.player.enabled = false
	game.player.velocity = Vector3.ZERO
	board.show()
	var checks := ""
	for pair in [["signal","Сигнал спасателям"],["hull","Корпус: 5 дерева + 2 детали"],["engine","Двигатель: 4 детали"],["ship_fuel","Бак: 3 топлива"],["stores","Провизия: 3 готовых блюда"]]:
		checks += ("✓ " if state[pair[0]] else "○ ")+pair[1]+"\n"
	board_text.text = "ДЕНЬ %d / 30 — %s\n\n%s\n\nКАТЕР «СЕВЕРНЫЙ»\n%s\nВыход: с 7-го дня, только днём.\n\nРЮКЗАК\nДетали: %d · Инструменты: %s\nДерево: %d · Топливо: %d · Еда: %d\n\nКаждое утро: детали на складе, топливо\nв гавани, северный валежник и вода.\nНочью: сон в укреплённой хижине.\nДни 8–30: припасы, ловушка, вода, костёр.\nM / E / Esc — вернуться на остров" % [game.day,title(),objective(),checks,int(state.scrap),"есть" if state.tools else "нет",game.inventory.wood,game.inventory.fuel,game.food_items.size()]
	if game.campaign.enabled:
		board_text.add_theme_font_size_override("font_size",15)
		board_text.text = game.campaign.board_summary(checks)
	else:board_text.add_theme_font_size_override("font_size",17)

func close_board() -> void:
	board.hide()
	game.paused = false
	game.player.enabled = true
	game.interaction_cooldown = 0.35

func build_board() -> void:
	var hud = game.hud
	board = Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.root.add_child(board)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01,0.025,0.03,0.93)
	board.add_child(shade)
	hud.panel(board,Rect2(150,90,1140,720),Color("142b2d"))
	hud.text(board,"ОСТРОВ СЕВЕРНЫЙ   /   ПЛАН ЭВАКУАЦИИ",Rect2(185,112,1000,32),22,Color("d9bc84"))
	var map := Control.new()
	map.set_script(MAP)
	map.game = game
	map.large = true
	map.position = Vector2(175,177)
	map.size = Vector2(540,535)
	board.add_child(map)
	board_text = hud.text(board,"",Rect2(755,170,510,590),17)
	board_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close = hud.make_button(board,"Вернуться на остров · M / Esc",Vector2(185,742),close_board,true)
	close.size = Vector2(490,42)
