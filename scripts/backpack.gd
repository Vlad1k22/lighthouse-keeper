extends Control
## The backpack is a view of the same items the world interactions and saves use.
const CATEGORIES := ["Материалы","Улов","Еда","Снаряжение"]
const MATERIALS := [
	["Древесина","Верстак, ремонт корпуса и костёр. Для первого укрепления нужны три единицы."],
	["Топливо","Канистры для генератора и катера. На переход нужно три канистры."],
	["Детали","Детали со склада идут на ремонт насоса, передатчика и двигателя."],
]
var game: Node
var hud: CanvasLayer
var list: ItemList
var caption: Label
var details: Label
var summary: Label
var feedback: Label
var first: Button
var second: Button
var third: Button
var tab_buttons: Array[Button] = []
var category := 0

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	game = hud.game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.014,.032,.036,.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	hud.panel(self,Rect2(168,111,1104,678),Color("142b30"))
	hud.text(self,"ОСТРОВ СЕВЕРНЫЙ   /   СНАРЯЖЕНИЕ",Rect2(214,146,710,25),14,hud.GOLD)
	hud.text(self,"Рюкзак",Rect2(210,176,430,51),36)
	summary = hud.text(self,"",Rect2(214,238,1016,27),16,hud.MUTED)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(213,283)
	tabs.size = Vector2(1014,48)
	tabs.add_theme_constant_override("separation",10)
	add_child(tabs)
	var group := ButtonGroup.new()
	for i in CATEGORIES.size():
		var tab := Button.new()
		tab.text = CATEGORIES[i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",18)
		tab.add_theme_stylebox_override("normal",hud.style(Color("102429"),Color("2c4b4e")))
		tab.add_theme_stylebox_override("pressed",hud.style(Color("47615c"),Color("d7b77f")))
		tab.add_theme_stylebox_override("hover_pressed",hud.style(Color("536d65"),Color("d7b77f")))
		tabs.add_child(tab)
		tab_buttons.append(tab)
		tab.pressed.connect(func(): show_category(i))
	list = ItemList.new()
	list.position = Vector2(213,351)
	list.size = Vector2(472,339)
	list.add_theme_font_size_override("font_size",17)
	list.add_theme_constant_override("v_separation",13)
	list.add_theme_stylebox_override("panel",hud.style(Color("0e2226"),Color("345052")))
	add_child(list)
	list.item_selected.connect(func(_index): refresh_details())
	caption = hud.text(self,"",Rect2(721,351,504,58),22,hud.GOLD)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details = hud.text(self,"",Rect2(721,421,504,126),17)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	first = hud.make_button(self,"",Vector2(721,556),primary_action,true)
	second = hud.make_button(self,"",Vector2(721,614),secondary_action)
	third = hud.make_button(self,"",Vector2(721,672),tertiary_action)
	for button in [first,second,third]:
		button.size.x = 410
	feedback = hud.text(self,"",Rect2(214,699,490,36),14,hud.GOLD)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.make_button(self,"Закрыть · B / Esc",Vector2(213,731),close).size.x = 239
	hide()

func open() -> void:
	if visible:
		return
	game.paused = true
	game.player.enabled = false
	feedback.text = ""
	show()
	show_category(category)
	list.grab_focus()

func close() -> void:
	if not visible:
		return
	hide()
	game.paused = false
	game.player.enabled = game.playing and not game.finished

func show_category(index: int) -> void:
	category = index
	for i in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(i==index)
	refresh()

func selected_index() -> int:
	var indices := list.get_selected_items()
	return -1 if indices.is_empty() else indices[0]

func refresh(preferred: int = -1) -> void:
	summary.text = "Здоровье %d  ·  Сытость %d  ·  Рассудок %d  ·  Тепло %d%%" % [roundi(game.health),roundi(game.hunger),roundi(game.sanity),roundi(game.survival.warmth)]
	list.clear()
	match category:
		0:
			var quantities := [game.inventory.wood,game.inventory.fuel,int(game.expedition.state.scrap)]
			for i in MATERIALS.size():
				list.add_item("%s   ×%d" % [MATERIALS[i][0],quantities[i]])
		1,2:
			var items: Array = game.fish_items if category==1 else game.food_items
			for i in items.size():
				var item: Dictionary = items[i]
				var pinned: bool = i==(game.selected_fish if category==1 else game.selected_food)
				list.add_item(("◆  " if pinned else "     ")+game.PROVISIONS.label(item))
				list.set_item_custom_fg_color(i,game.PROVISIONS.rarity_color(item))
		3:
			list.add_item("Ручной фонарь")
			list.add_item("Фляга   %d/%d" % [game.survival.water,game.survival.FLASK_CAPACITY])
			if game.expedition.state.tools:list.add_item("Набор инструментов")
			if game.expedition.state.battery and not game.expedition.state.signal:list.add_item("Аккумулятор передатчика")
	if list.item_count>0:
		if preferred<0:
			preferred = game.selected_fish if category==1 else (game.selected_food if category==2 else 0)
		var row := clampi(preferred,0,list.item_count-1)
		list.select(row)
		list.ensure_current_is_visible()
	refresh_details()

func refresh_details() -> void:
	first.hide()
	second.hide()
	third.hide()
	var index := selected_index()
	if index<0:
		caption.text = "Здесь пока пусто"
		details.text = "Улов можно добыть на причале." if category==1 else "Приготовьте рыбу на печи или найдите паёк."
		return
	match category:
		0:
			caption.text = MATERIALS[index][0]
			details.text = MATERIALS[index][1]
		1:
			var item: Dictionary = game.fish_items[index]
			caption.text = str(item.name)
			details.text = "%s · %d г\nПриготовьте на печи или используйте для ловушки.\n◆ — выбранная рыба для действия на E." % [game.PROVISIONS.rarity_name(item),item.weight]
			_offer(first,"Выбрать этот улов")
			_offer(second,"Приготовить на печи",_station("cook")!=null)
			_offer(third,"Поставить наживку",_station("trap")!=null and int(game.expedition.state.trap_day)==0)
		2:
			var item: Dictionary = game.food_items[index]
			var benefits: Dictionary = game.PROVISIONS.bonuses(item)
			caption.text = str(item.name)
			details.text = "Здоровье +%d   ·   Сытость +%d\n◆ — блюдо на быстрой клавише R." % [benefits.health,benefits.hunger]
			var soup: bool = item.get("recipe","")==game.survival.SOUP
			if soup:
				details.text += "\nСогревает на холоде."
			_offer(first,"Съесть выбранное",game.health<100 or game.hunger<100 or (soup and game.survival.warmth<100))
			_offer(second,"Назначить на R")
		3:
			caption.text = list.get_item_text(index)
			match index:
				0:
					details.text = "Фонарь отпугивает часть теней. Быстрая клавиша F."
					_offer(first,"Выключить фонарь" if game.player.lantern_on else "Включить фонарь")
				1:
					details.text = "Вода восстанавливает выносливость и рассудок. Порция также нужна для ухи."
					_offer(first,"Выпить",game.survival.water>0)
					_offer(second,"Наполнить у насоса",game.survival.can_refill() and game.survival.water<game.survival.FLASK_CAPACITY)
				_:
					details.text = "Используется при ремонте оборудования." if caption.text=="Набор инструментов" else "Нужен для передатчика. Устанавливается при его ремонте."

func _offer(button: Button, label: String, available := true) -> void:
	button.text = label
	button.disabled = not available
	button.show()

func _station(id: String) -> Area3D:
	return null if game.campaign.reserves_action(id) else game.near_station(id)

func primary_action() -> void:
	var index := selected_index()
	if index<0:return
	match category:
		1:
			game.selected_fish = index
			feedback.text = "Улов выбран."
		2:
			game.selected_food = index
			if game.eat():
				feedback.text = "Блюдо съедено."
		3:
			if index==0:game.player.toggle_lantern()
			if index==1:
				game.survival.drink()
				feedback.text = game.message
	refresh(index)

func secondary_action() -> void:
	var index := selected_index()
	if index<0:return
	if category==2:
		game.selected_food = index
		feedback.text = "Блюдо назначено на R."
		refresh(index)
	elif category==1:
		_use_fish("cook",index)
	elif category==3 and index==1:
		game.survival.refill()
		feedback.text = game.message
		refresh(index)

func tertiary_action() -> void:
	var index := selected_index()
	if category==1 and index>=0 and int(game.expedition.state.trap_day)==0:
		_use_fish("trap",index)

func _use_fish(id: String, index: int) -> void:
	var station := _station(id)
	if station==null:return
	game.selected_fish = index
	close()
	game.attempt_interaction(station)
