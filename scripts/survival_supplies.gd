extends RefCounted
## Optional supplies and exposure. Existing quest preparation still uses its original checks.
const FLASK_CAPACITY := 3
const SOUP := "soup"
const SMOKED := "smoked"
var game: Node
var water := 0
var warmth := 85.0
var stove_time := 0.0
var meal_warmth_time := 0.0
var wood_bonus_day := 0

func reset() -> void:
	water = 0
	warmth = 85.0
	stove_time = 0.0
	meal_warmth_time = 0.0
	wood_bonus_day = 0
	game.player.stamina_recovery_scale = 1.0

func save_state() -> Dictionary:
	return {"water":water,"warmth":warmth,"stove_time":stove_time,"meal_warmth_time":meal_warmth_time,"wood_bonus_day":wood_bonus_day}

func restore(data: Variant) -> void:
	if not data is Dictionary:return
	water = clampi(int(data.get("water",0)),0,FLASK_CAPACITY)
	warmth = clampf(float(data.get("warmth",85)),0,100)
	stove_time = clampf(float(data.get("stove_time",0)),0,160)
	meal_warmth_time = clampf(float(data.get("meal_warmth_time",0)),0,85)
	wood_bonus_day = maxi(0,int(data.get("wood_bonus_day",0)))

func exposure_enabled() -> bool:
	return game.campaign.enabled and game.campaign.calendar_days()==14 and not game.first_shift_demo.active()

func advance(delta: float) -> void:
	stove_time = maxf(0,stove_time-delta)
	meal_warmth_time = maxf(0,meal_warmth_time-delta)
	if not exposure_enabled():
		game.player.stamina_recovery_scale = 1.0
		return
	var at_home: bool = game.building_interiors.active=="cabin"
	var sheltered: bool = not game.building_interiors.active.is_empty() or game.lighthouse_interior.active or game.building_interiors.warehouse_open
	var near_fire: bool = int(game.expedition.state.fire_day)==game.day and game.player.position.distance_to(Vector3(-16,1,-26.7))<5.0
	var change := .55 if sheltered else .28
	if near_fire or (at_home and stove_time>0):
		change = 3.6
	elif not sheltered:
		var rain: float = game.coastal_life.rain_strength
		var severity := 1.0 if game.day<5 else (1.35 if game.day<10 else 1.75)
		change -= severity*(rain*.62+(.50 if game.is_night() else 0.0))
	if meal_warmth_time>0:
		change += .72
	warmth = clampf(warmth+change*delta,0,100)
	game.player.stamina_recovery_scale = lerpf(.62,1.0,smoothstep(10,48,warmth))

func can_refill() -> bool:
	return game.expedition.state.pump and game.near_station("pump")!=null

func refill() -> bool:
	if not can_refill():
		game.notify("Наполните флягу у работающего насоса.")
		return false
	if water>=FLASK_CAPACITY:
		game.notify("Фляга уже полная.")
		return false
	water = FLASK_CAPACITY
	game.notify("Фляга наполнена · %d порции чистой воды." % water)
	game.sound.interact()
	return true

func drink() -> bool:
	if water<=0:
		game.notify("Фляга пуста. Наберите воды у насоса.")
		return false
	if game.player.stamina>=99.9 and game.sanity>=99.9:
		game.notify("Вы бодры. Воду можно оставить на дорогу или для ухи.")
		return false
	water -= 1
	game.player.stamina = minf(100,game.player.stamina+24)
	game.sanity = minf(100,game.sanity+5)
	game.notify("Вода помогла отдышаться. Осталось порций: %d." % water)
	game.sound.interact()
	return true

func light_stove() -> bool:
	if game.near_station("cook")==null or game.inventory.wood<1 or stove_time>25:
		return false
	game.inventory.wood -= 1
	stove_time = 160.0
	game.notify("Печь растоплена. В хижине теплее, пока горят дрова.")
	game.sound.interact("cook")
	return true

func can_cook(recipe: String, index: int) -> bool:
	if game.near_station("cook")==null or index<0 or index>=game.fish_items.size():
		return false
	return (recipe==SOUP and water>=1) or (recipe==SMOKED and game.inventory.wood>=1)

func cook(recipe: String, index: int, quality: bool) -> bool:
	if not can_cook(recipe,index):
		return false
	var meal: Dictionary = game.PROVISIONS.crafted(game.fish_items[index],recipe,quality)
	if recipe==SOUP:
		water -= 1
	else:
		game.inventory.wood -= 1
	game.fish_items.remove_at(index)
	game.food_items.append(meal)
	game.selected_food = game.food_items.size()-1
	game.sync_provisions()
	game.campaign.observe("cook",true)
	game.sound.interact("cook")
	game.notify("Готово · %s%s." % [game.PROVISIONS.label(meal)," · удачный жар" if quality else ""])
	return true

func ate(meal: Dictionary) -> void:
	if meal.get("recipe","")==SOUP:
		var good := bool(meal.get("quality",false))
		warmth = minf(100,warmth+(38 if good else 27))
		meal_warmth_time = maxf(meal_warmth_time,85.0 if good else 60.0)
