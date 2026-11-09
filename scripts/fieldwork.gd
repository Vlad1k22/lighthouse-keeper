extends Control
## Three short activities share a work panel and one analogue gauge.
enum Mode { WOOD, FUEL, KITCHEN, COOK }
const DRY := "Звонкий стук · светлый торец"
const WET := ["Глухой стук · тёмный торец","Глухой стук · сырая кора"]
const TRACK := Rect2(418,434,604,25)
var game: Node
var hud: CanvasLayer
var mode := Mode.WOOD
var source: Area3D
var recipe := ""
var fish_index := 0
var dry_slot := 0
var title: Label
var instructions: Label
var meter_label: Label
var footer: Label
var buttons: Array[Button] = []
var track: ColorRect
var safe: ColorRect
var cursor: ColorRect
var gauge := 0.2
var elapsed := 0.0
var steady := 0.0
var holding := false
var bounds := Vector2(.40,.68)

func setup(owner: CanvasLayer) -> void:
	hud = owner
	game = hud.game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.014,.033,.036,.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	hud.panel(self,Rect2(368,179,704,542),Color("132b2e"))
	hud.text(self,"ОСТРОВ СЕВЕРНЫЙ   /   ПОДГОТОВКА",Rect2(418,213,604,26),14,hud.GOLD)
	title = hud.text(self,"",Rect2(418,257,604,46),31)
	instructions = hud.text(self,"",Rect2(418,321,604,106),17)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track = _strip(Color("0b2023"))
	track.position = TRACK.position
	track.size = TRACK.size
	safe = _strip(Color("77a893"))
	cursor = _strip(Color("f3d39b"))
	cursor.size = Vector2(6,TRACK.size.y+8)
	meter_label = hud.text(self,"",Rect2(418,469,604,30),16,hud.GOLD)
	for i in 3:
		var button: Button = hud.make_button(self,"",Vector2(418,426+i*55),func(): choose(i))
		button.size = Vector2(604,45)
		buttons.append(button)
	footer = hud.text(self,"",Rect2(418,608,604,34),14,hud.MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.make_button(self,"Закрыть · Esc",Vector2(418,659),close).size.x = 205
	hide()

func _strip(color: Color) -> ColorRect:
	var strip := ColorRect.new()
	strip.color = color
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	return strip

func available_at(station: Area3D) -> bool:
	if not is_instance_valid(station) or game.campaign.reserves_action(station.station_id):
		return false
	match station.station_id:
		"wood","north_wood":
			return game.survival.wood_bonus_day!=game.day and (station.station_id=="wood" or not game.expedition.used("north_wood"))
		"depot":
			return game.day>=2 and not game.expedition.used("depot")
	return false

func open_resource(station: Area3D) -> bool:
	if not available_at(station) or game.player.jump_in_progress:
		return false
	source = station
	if station.station_id=="depot":
		_open(Mode.FUEL)
		_start_gauge()
	else:
		_open(Mode.WOOD)
		title.text = "Сухие поленья"
		instructions.text = "Посмотрите на торцы и прислушайтесь к стуку. Выберите сухое полено для дополнительной охапки."
		dry_slot = (game.day*2+int(station.station_id=="north_wood"))%3
		for i in 3:
			buttons[i].text = "%d · %s" % [i+1,DRY if i==dry_slot else WET[i-int(i>dry_slot)]]
		footer.text = "Обычная охапка доступна после любого выбора."
	return true

func open_kitchen() -> void:
	if game.near_station("cook")==null or game.player.jump_in_progress:
		game.notify("Рецепты доступны у печи в хижине.")
		return
	_open(Mode.KITCHEN)
	_update_kitchen()

func _update_kitchen() -> void:
	title.text = "Печь и рецепты"
	var fish := "Улов: %s" % game.PROVISIONS.label(game.fish_items[game.selected_fish]) if not game.fish_items.is_empty() else "Для рецепта нужна рыба. Выберите улов в рюкзаке B."
	instructions.text = "%s\nВода %d/%d  ·  Древесина %d  ·  Жар печи %d сек." % [fish,game.survival.water,game.survival.FLASK_CAPACITY,game.inventory.wood,ceili(game.survival.stove_time)]
	buttons[0].text = "1 · Уха — рыба и порция воды"
	buttons[1].text = "2 · Копчёная рыба — рыба и древесина"
	buttons[2].text = "3 · Растопить печь — 1 древесина"
	buttons[0].disabled = not game.survival.can_cook(game.survival.SOUP,game.selected_fish)
	buttons[1].disabled = not game.survival.can_cook(game.survival.SMOKED,game.selected_fish)
	buttons[2].disabled = game.inventory.wood<1 or game.survival.stove_time>25
	footer.text = "Уха согревает перед ночью. Копчёную рыбу в первую очередь грузят на катер."

func _open(next: Mode) -> void:
	mode = next
	var analogue := mode in [Mode.FUEL,Mode.COOK]
	for item in [track,safe,cursor,meter_label]:item.visible = analogue
	for button in buttons:
		button.visible = not analogue
		button.disabled = false
	game.paused = true
	game.player.enabled = false
	show()

func choose(index: int) -> void:
	if not visible or index<0 or index>=buttons.size() or not buttons[index].visible or buttons[index].disabled:
		return
	if mode==Mode.WOOD:
		var target := source
		var accurate := index==dry_slot
		close()
		if game.attempt_interaction(target):
			game.survival.wood_bonus_day = game.day
			if accurate:game.inventory.wood += 1
			game.notify("Сухое полено найдено · к обычному сбору +1 дерево." if accurate else "Это полено влажное. Обычная охапка собрана.")
	elif mode==Mode.KITCHEN:
		if index==2:
			game.survival.light_stove()
			_update_kitchen()
			return
		recipe = game.survival.SOUP if index==0 else game.survival.SMOKED
		fish_index = game.selected_fish
		_open(Mode.COOK)
		_start_gauge()

func _start_gauge() -> void:
	holding = false
	gauge = .24
	elapsed = 0
	steady = 0
	var center := .58 if mode==Mode.FUEL else (.53 if recipe==game.survival.SOUP else .43)
	var tolerance := .16 if game.day<5 else (.135 if game.day<10 else .11)
	bounds = Vector2(center-tolerance,center+tolerance)
	safe.position = TRACK.position+Vector2(bounds.x*TRACK.size.x,0)
	safe.size = Vector2((bounds.y-bounds.x)*TRACK.size.x,TRACK.size.y)
	title.text = "Давление насоса" if mode==Mode.FUEL else "Жар печи"
	instructions.text = "Держите Пробел, чтобы поднять %s. Отпускайте, чтобы удерживать метку в зелёной зоне." % ("давление" if mode==Mode.FUEL else "жар")
	footer.text = "Стабильное давление даёт дополнительную канистру." if mode==Mode.FUEL else "Ровный жар улучшает блюдо. При отмене продукты остаются в рюкзаке."
	_update_gauge()

func _process(delta: float) -> void:
	if visible and mode in [Mode.FUEL,Mode.COOK]:
		tick(delta,holding)

func tick(delta: float, held: bool) -> void:
	elapsed += delta
	gauge = clampf(gauge+delta*(.43 if held else -.30),0,1)
	if gauge>=bounds.x and gauge<=bounds.y:
		steady += delta
	_update_gauge()
	if steady>=2.65 or elapsed>=8.0:
		_finish(steady>=2.65)

func _update_gauge() -> void:
	cursor.position = TRACK.position+Vector2(gauge*TRACK.size.x-3,-4)
	meter_label.text = "В зелёной зоне %.1f / 2,7 сек.   ·   Осталось %.1f сек." % [minf(steady,2.65),maxf(0,8-elapsed)]

func _finish(accurate: bool) -> void:
	var target := source
	var fuel := mode==Mode.FUEL
	var before: int = game.inventory.fuel
	close()
	if fuel:
		if game.attempt_interaction(target) and game.inventory.fuel==before+2 and accurate:
			game.inventory.fuel += 1
			game.notify("Давление удержано. Топливо +3, включая бонусную канистру.")
	else:
		game.survival.cook(recipe,fish_index,accurate)

func handle(event: InputEventKey) -> void:
	if event.physical_keycode==KEY_SPACE:
		holding = event.pressed
	if not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_ESCAPE:close()
		KEY_1,KEY_KP_1:choose(0)
		KEY_2,KEY_KP_2:choose(1)
		KEY_3,KEY_KP_3:choose(2)

func close() -> void:
	hide()
	source = null
	holding = false
	game.paused = false
	game.player.enabled = game.playing and not game.finished
