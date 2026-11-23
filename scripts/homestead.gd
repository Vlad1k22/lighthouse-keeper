extends Node3D
## Хозяйство смотрителя: каменоломня, застройка хижины укреплениями, огород и вороны.
## Даёт занятие днём: камень и дерево превращаются в прочность хижины ночью,
## грядки кормят смотрителя, но их нужно поливать и охранять от птиц.
const Geo = preload("res://scripts/geometry.gd")
const STATION = preload("res://scripts/interactable.gd")
const PROVISIONS = preload("res://scripts/provisions.gd")
const QUARRY := Vector3(11.4, 1, -15.8)
const QUARRY_ROCK := Vector3(12.6, 1, -17.4)
const QUARRY_DAILY := 4
const BARREL := Vector3(15.8, 1, 0.6)
const CAN_SIZE := 4
const GROW_SECONDS := 32.0
## Участки укреплений вокруг хижины: уровень 1 — дерево, 2 — камень.
const SLOTS := [
	{"id":"fort_front","name":"крыльцо","at":Vector3(4.8,1,5.3),"yaw":0.0,"front":true},
	{"id":"fort_n","name":"задняя стена","at":Vector3(5.0,1,-3.6),"yaw":0.0},
	{"id":"fort_ne","name":"северо-восточный угол","at":Vector3(9.1,1,-3.0),"yaw":-0.7},
	{"id":"fort_nw","name":"северо-западный угол","at":Vector3(1.7,1,-3.7),"yaw":0.5},
	{"id":"fort_e","name":"восточные окна","at":Vector3(10.4,1,-1.0),"yaw":PI/2},
	{"id":"fort_w","name":"западные окна","at":Vector3(-1.3,1,-1.6),"yaw":PI/2},
	{"id":"fort_se","name":"частокол у крыльца","at":Vector3(8.6,1,4.8),"yaw":0.0}
]
const WOOD_COST := 3
const STONE_COST := 4
const BEDS := [Vector3(12.2,1,-0.6), Vector3(14.2,1,-0.6), Vector3(12.2,1,1.9)]
const CROPS := [
	{"name":"Морковь","color":Color("e07a2e")},
	{"name":"Репа","color":Color("d9c2e0")},
	{"name":"Картофель","color":Color("b08a5a")}
]
const STAGE_NAMES := ["пусто","посев","всходы","куст","урожай"]

var game: Node
var stations: Array = []
var levels := {}
var slot_nodes := {}
var quarry_used := 0
var quarry_day := -1
var can_water := 0
var beds: Array = []
var bed_nodes: Array = []
var birds: Array = []
var bird_clock := 0.0
var next_bird := 40.0
var scared := 0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func setup() -> void:
	_build_quarry()
	_make_station("quarry", "Каменоломня · добыть камень", QUARRY)
	for slot in SLOTS:
		if not slot.get("front", false):
			_make_station(slot.id, "Укрепить: " + slot.name, slot.at)
	_make_station("rain_barrel", "Бочка с дождевой водой · наполнить лейку", BARREL)
	Geo.barrel(self, BARREL + Vector3(.35, 0, -.35), .9)
	for i in BEDS.size():
		_make_station("bed_%d" % i, "Грядка", BEDS[i])
		bed_nodes.append(_build_bed(BEDS[i]))
	reset()

func reset() -> void:
	levels.clear()
	for slot in SLOTS:
		levels[slot.id] = 0
	quarry_used = 0
	quarry_day = -1
	can_water = 0
	beds.clear()
	for i in BEDS.size():
		beds.append({"stage":0,"water":false,"grow":0.0,"crop":i % CROPS.size(),"bird":false})
	for bird in birds:
		if is_instance_valid(bird.node):
			bird.node.queue_free()
	birds.clear()
	bird_clock = 0
	next_bird = 40
	scared = 0
	_refresh_visuals()

# ---------------------------------------------------------------- станции

func _make_station(id: String, title: String, at: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Station_" + id
	area.set_script(STATION)
	area.set("station_id", id)
	area.set("display_name", title)
	area.set("remaining", -1)
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	shape.shape = sphere
	shape.position.y = .8
	area.add_child(shape)
	var marker := Label3D.new()
	marker.name = "InteractionMarker"
	marker.text = "◆"
	marker.font_size = 38
	marker.pixel_size = .014
	marker.position.y = 2.3
	marker.modulate = Color("e3bb76")
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(marker)
	var ring := MeshInstance3D.new()
	ring.name = "SelectionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = .64
	torus.outer_radius = .69
	ring.mesh = torus
	ring.position.y = .08
	ring.material_override = Geo.material(Color("e4c485"), .5)
	ring.visible = false
	area.add_child(ring)
	game.world.add_child(area)
	area.set("near_only", id.begins_with("fort_") or id.begins_with("bed_"))
	stations.append(area)
	game.stations.append(area)

func station(id: String) -> Area3D:
	for item in stations:
		if item.station_id == id:
			return item
	return null

func owns(id: String) -> bool:
	return id == "quarry" or id == "rain_barrel" or id.begins_with("fort_") or id.begins_with("bed_")

## Верстак после постройки баррикады предлагает обложить крыльцо камнем.
func front_upgrade_available() -> bool:
	return game.barricade_built and int(levels.fort_front) < 2

# ---------------------------------------------------------------- состояние за кадр

func advance(delta: float) -> void:
	if quarry_day != game.day:
		quarry_day = game.day
		quarry_used = 0
	_update_stations()
	_grow(delta)
	_birds(delta)

func _update_stations() -> void:
	for item in stations:
		item.proximity = Vector2(game.player.position.x - item.position.x, game.player.position.z - item.position.z).length()
	for slot in SLOTS:
		var item := station(slot.id)
		if item == null:
			continue
		var level: int = levels[slot.id]
		var unlocked: bool = game.barricade_built or level > 0
		item.remaining = 0 if level >= 2 or not unlocked else -1
		item.display_name = ("Укрепить «%s» · %d дерева" % [slot.name, WOOD_COST]) if level == 0 else ("Обложить камнем «%s» · %d камня" % [slot.name, STONE_COST])
	for item in game.stations:
		if item.station_id == "workbench":
			item.display_name = ("Обложить крыльцо камнем · %d камня" % STONE_COST) if front_upgrade_available() else "Верстак · укрепление"
	var quarry := station("quarry")
	quarry.remaining = 0 if quarry_used >= QUARRY_DAILY else -1
	quarry.display_name = "Каменоломня · добыть камень (%d / %d сегодня)" % [quarry_used, QUARRY_DAILY]
	station("rain_barrel").display_name = "Бочка с водой · наполнить лейку (%d / %d)" % [can_water, CAN_SIZE]
	for i in beds.size():
		var bed: Dictionary = beds[i]
		var crop: Dictionary = CROPS[bed.crop]
		var item := station("bed_%d" % i)
		match int(bed.stage):
			0: item.display_name = "Грядка · посадить: %s" % String(crop.name).to_lower()
			4: item.display_name = "Грядка · собрать урожай: %s" % String(crop.name).to_lower()
			_: item.display_name = ("Грядка · %s растёт" % STAGE_NAMES[bed.stage]) if bed.water else ("Грядка · полить (%s)" % STAGE_NAMES[bed.stage])

## Действия у станций хозяйства. 1 — выполнено, 0 — отказ, -1 — не наша станция.
func intercept(id: String) -> int:
	if id == "workbench" and front_upgrade_available():
		return 1 if fortify("fort_front") else 0
	if not owns(id):
		return -1
	if id == "quarry":
		return 1 if mine(game.minigame_result == "done") else 0
	if id == "rain_barrel":
		if can_water >= CAN_SIZE:
			game.notify("Лейка уже полная. Полейте грядки у хижины.")
			return 0
		can_water = CAN_SIZE
		game.sound.interact("fish")
		game.feedback(BARREL, "Лейка полна · %d полива" % CAN_SIZE)
		return 1
	if id.begins_with("fort_"):
		return 1 if fortify(id) else 0
	if id.begins_with("bed_"):
		return 1 if tend(int(id.trim_prefix("bed_"))) else 0
	return -1

# ---------------------------------------------------------------- каменоломня

func mine(skilled: bool) -> bool:
	if quarry_used >= QUARRY_DAILY:
		game.notify("Сегодня отбит весь камень, что можно поднять. Возвращайтесь завтра.")
		return false
	if not game.expedition.state.tools:
		game.notify("Без кирки не выйдет. Инструменты лежат на старом складе на севере.")
		return false
	quarry_used += 1
	var amount := 2 + (1 if skilled else 0)
	game.inventory.stone = int(game.inventory.get("stone", 0)) + amount
	game.hunger = maxf(0, game.hunger - 4)
	game.sound.interact("wood")
	game.camera_shake = maxf(game.camera_shake, .3)
	game.feedback(QUARRY_ROCK, "+%d КАМНЯ" % amount)
	game.notify("Камень +%d. Камнем можно обложить укрепления вокруг хижины." % amount)
	return true

func _build_quarry() -> void:
	var root := Node3D.new()
	root.name = "Quarry"
	add_child(root)
	root.global_position = QUARRY_ROCK
	for spec in [[Vector3(0,0,0), Vector3(2.6,1.9,2.2), .2], [Vector3(1.5,0,1.0), Vector3(1.6,1.2,1.4), .9], [Vector3(-1.4,0,.5), Vector3(1.4,1.0,1.2), 1.7], [Vector3(.3,0,1.7), Vector3(.9,.5,.8), 2.4], [Vector3(-.6,0,-1.2), Vector3(1.8,1.3,1.5), 3.1]]:
		Geo.rock(root, spec[0], spec[1], Color("4b524f"), spec[2])
	var dust := Geo.box(root, "Gravel", Vector3(-.4, .03, 1.4), Vector3(3.2, .05, 1.8), Color("6a6f6b"))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:
		var chip := Geo.box(root, "Chip", Vector3(-1.4 + i * .5, .08, 1.6 + rng.randf_range(-.3, .3)), Vector3(.22, .12, .18), Color("8b918c"))
		chip.rotation.y = rng.randf() * TAU
	var pick := Geo.box(root, "PickHandle", Vector3(-.6, .55, 1.1), Vector3(.06, .06, .9), Color("7a5a3a"))
	pick.rotation = Vector3(.6, .4, 0)
	var head := Geo.box(root, "PickHead", Vector3(-.6, .85, .78), Vector3(.5, .07, .07), Color("5c6266"))
	head.rotation = Vector3(.6, .4, 0)

# ---------------------------------------------------------------- укрепления

func fortify(id: String) -> bool:
	var slot := _slot(id)
	var level: int = levels[id]
	if slot.get("front", false):
		if not game.barricade_built:
			game.notify("Сначала поставьте основную баррикаду у верстака.")
			return false
		level = maxi(level, 1)
	if level == 0:
		if game.inventory.wood < WOOD_COST:
			game.notify("Нужно %d дерева. Валежник — к западу от хижины." % WOOD_COST)
			return false
		game.inventory.wood -= WOOD_COST
		levels[id] = 1
		game.feedback(slot.at, "Деревянный заслон · %s" % slot.name)
	elif level == 1:
		if int(game.inventory.get("stone", 0)) < STONE_COST:
			game.notify("Нужно %d камня. Каменоломня — на поляне к северу, у берега." % STONE_COST)
			return false
		game.inventory.stone = int(game.inventory.stone) - STONE_COST
		levels[id] = 2
		game.feedback(slot.at, "Каменная кладка · %s" % slot.name)
	else:
		return false
	game.sound.interact("wood")
	game.sound.cue("chime")
	game.camera_shake = maxf(game.camera_shake, .2)
	game.night_raids.barricade_hp = minf(game.night_raids.max_hp(), game.night_raids.barricade_hp + 40)
	_refresh_visuals()
	game.notify("Хижина крепче: прочность баррикады %d. Каменные стены ещё и гасят удары теней." % roundi(game.night_raids.max_hp()))
	return true

func _slot(id: String) -> Dictionary:
	for slot in SLOTS:
		if slot.id == id:
			return slot
	return {}

func wood_slots() -> int:
	var count := 0
	for slot in SLOTS:
		if int(levels[slot.id]) >= 1 and not slot.get("front", false):
			count += 1
	return count

func stone_slots() -> int:
	var count := 0
	for slot in SLOTS:
		if int(levels[slot.id]) >= 2:
			count += 1
	return count

## Добавка к прочности баррикады и доля урона, которую гасят каменные стены.
func bonus_hp() -> float:
	return wood_slots() * 30.0 + stone_slots() * 45.0

func armor() -> float:
	return minf(.6, stone_slots() * .08)

func _refresh_visuals() -> void:
	for slot in SLOTS:
		var id: String = slot.id
		var level: int = levels.get(id, 0)
		if slot_nodes.has(id) and is_instance_valid(slot_nodes[id]):
			slot_nodes[id].queue_free()
			slot_nodes.erase(id)
		if level <= 0 or (slot.get("front", false) and level < 2):
			continue
		var root := Node3D.new()
		root.name = "Fort_" + id
		add_child(root)
		root.global_position = slot.at + (Vector3(0, 0, .55) if slot.get("front", false) else Vector3.ZERO)
		root.rotation.y = slot.yaw
		if level == 1:
			for x in [-1.1, -.37, .37, 1.1]:
				Geo.box(root, "Post", Vector3(x, .65, 0), Vector3(.15, 1.3, .17), Color("8a7352"))
			for y in [.45, .95]:
				Geo.box(root, "Plank", Vector3(0, y, .1), Vector3(2.5, .2, .07), Color("a58a5f"))
			var brace := Geo.box(root, "Brace", Vector3(0, .7, .15), Vector3(2.4, .1, .07), Color("6f5c40"))
			brace.rotation.z = .35
		else:
			for row in 3:
				for col in 5:
					var stone := Geo.box(root, "Stone", Vector3(-1.1 + col * .55 + (row % 2) * .25, .2 + row * .34, 0), Vector3(.5, .3, .42), Color("7d8480").lerp(Color("5d6461"), rng.randf()))
					stone.rotation = Vector3(rng.randf_range(-.06, .06), rng.randf_range(-.15, .15), rng.randf_range(-.06, .06))
			Geo.box(root, "Cap", Vector3(0, 1.08, 0), Vector3(2.8, .1, .5), Color("8b918c"))
		slot_nodes[id] = root

# ---------------------------------------------------------------- огород

func _build_bed(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "GardenBed"
	add_child(root)
	root.global_position = at
	Geo.box(root, "Soil", Vector3(0, .1, 0), Vector3(1.5, .2, 1.1), Color("3c2c20"))
	for x in [-.78, .78]:
		Geo.box(root, "Board", Vector3(x, .14, 0), Vector3(.08, .28, 1.2), Color("7a6142"))
	for z in [-.58, .58]:
		Geo.box(root, "Board", Vector3(0, .14, z), Vector3(1.6, .28, .08), Color("7a6142"))
	var plants := Node3D.new()
	plants.name = "Plants"
	root.add_child(plants)
	return root

func tend(index: int) -> bool:
	if index < 0 or index >= beds.size():
		return false
	var bed: Dictionary = beds[index]
	var crop: Dictionary = CROPS[bed.crop]
	var stage: int = bed.stage
	if stage == 0:
		bed.stage = 1
		bed.water = false
		bed.grow = 0.0
		game.sound.interact("wood")
		game.feedback(BEDS[index], "Посажено: %s" % String(crop.name).to_lower())
		game.notify("Посажено. Теперь полейте грядку: лейку наполняет бочка с водой.")
	elif stage == 4:
		var item: Dictionary = {"kind":"veg","name":String(crop.name),"rarity":"common","weight":rng.randi_range(180, 420)}
		game.food_items.append(item)
		game.sync_provisions()
		bed.stage = 0
		bed.crop = (int(bed.crop) + 1) % CROPS.size()
		game.sound.cue("chime")
		game.feedback(BEDS[index], "+ %s" % String(crop.name).to_upper())
		game.notify("Урожай: %s. Это еда — R, чтобы съесть. Грядку можно засеять снова." % String(crop.name).to_lower())
	elif bed.water:
		game.notify("Грядка полита, %s растёт. Следите, чтобы вороны не склевали." % STAGE_NAMES[stage])
		return false
	else:
		if can_water <= 0:
			game.notify("Лейка пуста. Наполните её у бочки с дождевой водой.")
			return false
		can_water -= 1
		bed.water = true
		bed.grow = 0.0
		game.sound.interact("fish")
		game.feedback(BEDS[index], "Полито · лейка %d/%d" % [can_water, CAN_SIZE])
	_refresh_bed(index)
	return true

func _grow(delta: float) -> void:
	for i in beds.size():
		var bed: Dictionary = beds[i]
		if bed.stage in [1, 2, 3] and bed.water and not bed.bird:
			bed.grow = float(bed.grow) + delta
			if bed.grow >= GROW_SECONDS:
				bed.stage = int(bed.stage) + 1
				bed.water = bed.stage == 4
				bed.grow = 0.0
				_refresh_bed(i)
				if bed.stage == 4:
					game.feedback(BEDS[i], "Урожай созрел!")

func _refresh_bed(index: int) -> void:
	var plants: Node3D = bed_nodes[index].get_node("Plants")
	for child in plants.get_children():
		child.queue_free()
	var bed: Dictionary = beds[index]
	var stage: int = bed.stage
	if stage == 0:
		return
	var crop: Dictionary = CROPS[bed.crop]
	var soil := Geo.box(plants, "Wet", Vector3(0, .205, 0), Vector3(1.4, .01, 1.0), Color("2a1e16") if bed.water else Color("4a3828"))
	soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if stage == 1:
		for i in 6:
			Geo.box(plants, "Seed", Vector3(-.5 + (i % 3) * .5, .23, -.25 + (i / 3) * .5), Vector3(.06, .03, .06), Color("c9b27a"))
		return
	var height: float = [0.0, 0.0, .18, .38, .48][stage]
	for i in 6:
		var at := Vector3(-.5 + (i % 3) * .5, .2, -.25 + (i / 3) * .5)
		for leaf in 3:
			var blade := Geo.box(plants, "Leaf", at + Vector3(0, height * .5, 0), Vector3(.05, height, .14), Color("4f8a3e").lerp(Color("6fae4e"), leaf * .3))
			blade.rotation = Vector3(.25, leaf * 2.1, .2)
		if stage == 4:
			Geo.sphere(plants, "Crop", at + Vector3(0, .24, 0), Vector3(.16, .12, .16), crop.color)

func ripe_or_growing() -> Array:
	var list := []
	for i in beds.size():
		if int(beds[i].stage) >= 2 and not beds[i].bird:
			list.append(i)
	return list

# ---------------------------------------------------------------- вороны

func _birds(delta: float) -> void:
	var day_time: bool = not game.is_night() and not (game.campaign.enabled and game.campaign.state.night)
	for bird in birds:
		_move_bird(bird, delta)
	birds = birds.filter(func(b): return b.state != "gone")
	if not day_time or game.day < 2:
		return
	bird_clock += delta
	var targets := ripe_or_growing()
	if bird_clock >= next_bird and birds.size() < 2 and not targets.is_empty():
		bird_clock = 0
		next_bird = rng.randf_range(32, 55)
		_spawn_bird(targets[rng.randi_range(0, targets.size() - 1)])

func _spawn_bird(index: int) -> void:
	var node := Node3D.new()
	node.name = "Crow"
	add_child(node)
	Geo.sphere(node, "Body", Vector3(0, .12, 0), Vector3(.22, .2, .4), Color("16181b"))
	Geo.sphere(node, "Head", Vector3(0, .24, .2), Vector3(.14, .14, .14), Color("1c1e22"))
	var beak := Geo.box(node, "Beak", Vector3(0, .23, .3), Vector3(.04, .04, .12), Color("3a3a2a"))
	beak.rotation.x = .2
	for side in [-1, 1]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		wing.position = Vector3(.1 * side, .16, 0)
		node.add_child(wing)
		Geo.box(wing, "Feathers", Vector3(.22 * side, 0, 0), Vector3(.42, .03, .26), Color("101215"))
	var from: Vector3 = BEDS[index] + Vector3(rng.randf_range(-14, 14), 9, rng.randf_range(-14, -6))
	node.global_position = from
	beds[index].bird = true
	var bird := {"node":node,"bed":index,"state":"fly","t":0.0,"from":from,"to":BEDS[index] + Vector3(rng.randf_range(-.4, .4), .25, rng.randf_range(-.3, .3)),"peck":0.0}
	birds.append(bird)
	game.sound.horror_cue("whisper", BEDS[index])
	game.alert("ВОРОНА НАД ОГОРОДОМ", "Подбегите к грядке или посветите лучом (ПКМ), иначе склюёт урожай", 4)

func _move_bird(bird: Dictionary, delta: float) -> void:
	var node: Node3D = bird.node
	if not is_instance_valid(node):
		bird.state = "gone"
		return
	bird.t = float(bird.t) + delta
	var flap := sin(float(bird.t) * 22.0) * .7
	node.get_node("WingL").rotation.z = flap if bird.state != "peck" else .1
	node.get_node("WingR").rotation.z = -flap if bird.state != "peck" else -.1
	match String(bird.state):
		"fly":
			var k := minf(1, float(bird.t) / 3.0)
			var arc := sin(k * PI) * 1.5
			node.global_position = Vector3(bird.from).lerp(bird.to, k) + Vector3(0, arc, 0)
			node.look_at(node.global_position + (Vector3(bird.to) - Vector3(bird.from)).normalized(), Vector3.UP, true)
			if k >= 1:
				bird.state = "peck"
				bird.t = 0.0
		"peck":
			node.rotation.x = -.35 + absf(sin(float(bird.t) * 8.0)) * .35
			if _scared(node.global_position):
				_scare(bird, true)
			elif float(bird.t) > 10.0:
				var bed: Dictionary = beds[bird.bed]
				bed.stage = maxi(1, int(bed.stage) - 1)
				bed.water = false
				bed.grow = 0.0
				_refresh_bed(bird.bed)
				game.feedback(BEDS[bird.bed], "Ворона склевала урожай")
				_scare(bird, false)
		"leave":
			node.global_position += Vector3(bird.away) * delta * 9.0 + Vector3(0, delta * 4.0, 0)
			if float(bird.t) > 3.0:
				node.queue_free()
				bird.state = "gone"

func _scared(at: Vector3) -> bool:
	var flat := Vector2(game.player.position.x - at.x, game.player.position.z - at.z).length()
	if flat < 3.2 and game.building_interiors.active.is_empty():
		return true
	return game.lantern_beam.focusing and game.lantern_beam.in_cone(at)

func _scare(bird: Dictionary, by_player: bool) -> void:
	beds[bird.bed].bird = false
	bird.state = "leave"
	bird.t = 0.0
	var away := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, -.3)).normalized()
	bird.away = away
	bird.node.look_at(bird.node.global_position + away, Vector3.UP, true)
	if by_player:
		scared += 1
		game.feedback(bird.node.global_position, "Кыш!")
		game.sound.interact("fish")

# ---------------------------------------------------------------- сохранение

func save_data() -> Dictionary:
	return {"levels":levels,"quarry_used":quarry_used,"quarry_day":quarry_day,"can":can_water,"beds":beds.map(func(b): return {"stage":b.stage,"water":b.water,"grow":b.grow,"crop":b.crop})}

func restore(data: Dictionary) -> void:
	reset()
	var saved_levels: Dictionary = data.get("levels", {})
	for slot in SLOTS:
		levels[slot.id] = clampi(int(saved_levels.get(slot.id, 0)), 0, 2)
	quarry_used = int(data.get("quarry_used", 0))
	quarry_day = int(data.get("quarry_day", -1))
	can_water = clampi(int(data.get("can", 0)), 0, CAN_SIZE)
	var saved_beds: Array = data.get("beds", [])
	for i in mini(saved_beds.size(), beds.size()):
		var b: Dictionary = saved_beds[i]
		beds[i] = {"stage":clampi(int(b.get("stage", 0)), 0, 4),"water":bool(b.get("water", false)),"grow":float(b.get("grow", 0)),"crop":clampi(int(b.get("crop", 0)), 0, CROPS.size() - 1),"bird":false}
	_refresh_visuals()
	for i in beds.size():
		_refresh_bed(i)
