extends Node3D
## Closed rooms share a door, cutaway camera and station routing. The warehouse is in-place.
const LOOK_OFFSET := Vector3(6.1, 8.1, 8.8)
const SHED := Vector3(7, 1, -31)
const SHED_ZOOM := 10.5
const MODELS := {
	"keeper_cabin": preload("res://assets/models/interiors/keeper_cabin.glb"),
	"radio_outpost": preload("res://assets/models/interiors/radio_outpost.glb"),
	"vessel_wheelhouse": preload("res://assets/models/interiors/vessel_wheelhouse.glb"),
	"warehouse": preload("res://assets/models/interiors/warehouse.glb"),
}
const ROOMS := {
	"cabin": {
		"asset": "keeper_cabin", "title": "Хижина смотрителя", "enter": "Войти в хижину",
		"exit": Vector3(5, 1.4, 2.97), "spawn": Vector3(0, .04, 1.67),
		"origin": Vector3(225, 25, 0), "size": Vector2(6.15, 4.55), "zoom": 7.7,
		"lights": [Vector3(-1.05, 2.02, -1.55), Vector3(2.05, 1.02, -1.17)],
	},
	"radio": {
		"asset": "radio_outpost", "title": "Радиостанция", "enter": "Войти в радиостанцию",
		"exit": Vector3(-10.53, 1.04, -36.97), "spawn": Vector3(1.43, .04, 1.36),
		"origin": Vector3(244, 25, 0), "size": Vector2(5.0, 3.88), "zoom": 6.7,
		"lights": [Vector3(-1.68, 1.96, -1.37), Vector3(.36, 2.10, -.86)],
	},
	"ship": {
		"asset": "vessel_wheelhouse", "title": "Катер «Северный»", "enter": "Войти в рубку",
		"exit": Vector3(-2.77, 1.04, -4.55), "spawn": Vector3(-1.76, .04, 1.18),
		"origin": Vector3(263, 25, 0), "size": Vector2(4.7, 4.60), "zoom": 7.1,
		"lights": [Vector3(-1.61, 2.00, -1.70), Vector3(1.26, 1.91, 1.20)],
	},
}
var active := ""
var warehouse_open := false
var coast: Node3D
var vessel: Node3D
var warehouse: Node3D
var shed_cutaway: Array[Node3D] = []
var instances: Dictionary = {}
var actions: Dictionary = {}
var entrance_labels: Dictionary = {}
var room_env: Environment
var first_watch_glass: ShaderMaterial

func setup(world: Node3D) -> void:
	coast = world.get_node("NorthernCoast")
	vessel = coast.get_node("CoastalVessel")
	warehouse = _install("warehouse", SHED, coast)
	var forward := Vector2(LOOK_OFFSET.x, LOOK_OFFSET.z).normalized()
	for child in coast.get_children():
		if child.is_in_group("warehouse_replaced"):
			child.hide()
			for body in child.find_children("*", "StaticBody3D", true, false):
				body.collision_layer = 0
		if child.is_in_group("warehouse_cutaway"):
			shed_cutaway.append(child)
		if child.has_node("PineNeedleSprays"):
			var offset := Vector2(child.position.x-SHED.x, child.position.z-SHED.z)
			if offset.length()<12.0 and offset.dot(forward)>1.5 and absf(forward.cross(offset))<6.6:
				shed_cutaway.append(child)
	coast.get_node("RedToolbox").layers = 0
	_light(warehouse, Vector3(.53,2.02,-2.45), Color("ffc490"), 1.26, 5.6)
	for id in ROOMS:
		var label := Label3D.new()
		label.text = "◆  " + ROOMS[id].title
		label.font_size = 30
		label.pixel_size = .009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("e7bd83")
		world.add_child(label)
		label.hide()
		entrance_labels[id] = label
	room_env = Environment.new()
	room_env.background_mode = Environment.BG_COLOR
	room_env.background_color = Color("10191c")
	room_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room_env.ambient_light_color = Color("a9bdbd")
	room_env.ambient_light_energy = .43

func _install(asset: String, at: Vector3, parent: Node3D) -> Node3D:
	var packed: PackedScene = MODELS[asset]
	var room := packed.instantiate() as Node3D
	room.name = asset
	room.position = at
	parent.add_child(room)
	var body := StaticBody3D.new()
	body.name = "InteriorCollision"
	room.add_child(body)
	for marker in room.find_children("COL_*", "Node3D", true, false):
		var shape := BoxShape3D.new()
		shape.size = marker.global_basis.get_scale().abs()
		var collider := CollisionShape3D.new()
		collider.name = str(marker.name).trim_prefix("COL_")
		collider.shape = shape
		body.add_child(collider)
		collider.global_position = marker.global_position
	return room

func _light(room: Node3D, at: Vector3, tint: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = radius
	room.add_child(light)

func set_room(id: String) -> void:
	if active == id:
		return
	if not active.is_empty():
		instances[active].hide()
	active = id
	actions.clear()
	if id.is_empty():
		return
	set_warehouse(false)
	var info: Dictionary = ROOMS[id]
	if not instances.has(id):
		var room := _install(info.asset, info.origin, self)
		for section in ["Wall_South", "Wall_East", "BulkheadUpper"]:
			var wall := room.find_child(section, true, false) as Node3D
			if wall != null:
				wall.hide()
		_light(room, info.lights[0], Color("ffc78f"), 1.28, 5.0)
		_light(room, info.lights[1], Color("eac191") if id == "cabin" else Color("a5d0ce"), .82, 4.3)
		_floor_hint(room, info.spawn, "◇")
		if id=="cabin":
			add_window_apparition(room)
		instances[id] = room
	var current: Node3D = instances[id]
	current.show()
	for marker in current.find_children("ACT_*", "Node3D", true, false):
		var action := str(marker.name).trim_prefix("ACT_")
		actions[action] = marker.global_position
		if not marker.has_node("ActionHint"):
			_floor_hint(marker, Vector3.ZERO, "◆")

func add_window_apparition(room: Node3D) -> void:
	var pane := QuadMesh.new()
	pane.size = Vector2(1.03,.71)
	first_watch_glass = ShaderMaterial.new()
	first_watch_glass.shader = preload("res://shaders/first_watch_window.gdshader")
	var silhouette := MeshInstance3D.new()
	silhouette.name = "FirstWatchWindow"
	silhouette.mesh = pane
	silhouette.material_override = first_watch_glass
	silhouette.position = Vector3(-1.87,1.84,-2.154)
	room.add_child(silhouette)

func update_first_watch(strength: float, elapsed: float) -> void:
	if first_watch_glass == null:
		return
	first_watch_glass.set_shader_parameter("apparition", strength)
	first_watch_glass.set_shader_parameter("drift", clampf((elapsed-6.0)*.079, -.13, .26))

func _floor_hint(parent: Node3D, at: Vector3, icon: String) -> void:
	var label := Label3D.new()
	label.name = "ActionHint"
	label.text = icon
	label.font_size = 30
	label.pixel_size = .008
	label.modulate = Color("dfb976")
	label.position = at + Vector3.UP*.035
	label.rotation_degrees.x = -90
	parent.add_child(label)

func update_state(at: Vector3, playing: bool, hidden: bool, sailing: bool, tools: bool, signal_online: bool) -> void:
	set_warehouse(playing and not hidden and absf(at.x-SHED.x)<3.89 and at.z>SHED.z-2.88 and at.z<SHED.z+2.93 and absf(at.y-SHED.y)<1.45)
	for id in entrance_labels:
		var label: Label3D = entrance_labels[id]
		var door := exit_at(id)
		label.position = door + Vector3.UP*1.6
		label.visible = playing and not hidden and not sailing and at.distance_to(door)<4.3
	warehouse.find_child("ToolsPresent", true, false).visible = not tools
	if active == "radio":
		var room: Node3D = instances[active]
		room.find_child("SignalOn", true, false).visible = signal_online
		room.find_child("SignalOff", true, false).visible = not signal_online

func set_warehouse(value: bool) -> void:
	if warehouse_open == value:
		return
	warehouse_open = value
	for section in shed_cutaway:
		section.visible = not value

func exit_at(id: String) -> Vector3:
	var at: Vector3 = ROOMS[id].exit
	return vessel.global_position + at if id == "ship" else at

func spawn_at(id: String) -> Vector3:
	return ROOMS[id].origin + ROOMS[id].spawn

func contains(id: String, at: Vector3) -> bool:
	if not ROOMS.has(id):
		return false
	var local: Vector3 = at - ROOMS[id].origin
	var bounds: Vector2 = ROOMS[id].size
	return absf(local.x)<bounds.x*.5 and absf(local.z)<bounds.y*.5 and local.y>=-.18 and local.y<1.15

func door_at(at: Vector3) -> String:
	if not active.is_empty():
		return active if near(at, spawn_at(active), .67) else ""
	for id in ROOMS:
		if near(at, exit_at(id), .82 if id == "ship" else .91):
			return id
	return ""

func near(at: Vector3, target: Vector3, radius: float) -> bool:
	return absf(at.y-target.y)<.55 and Vector2(at.x-target.x, at.z-target.z).length()<radius

func station_distance(id: String, at: Vector3) -> float:
	if not actions.has(id):
		return INF
	var target: Vector3 = actions[id]
	return Vector2(at.x-target.x, at.z-target.z).length()

func prompt(at: Vector3) -> String:
	var door := door_at(at)
	if door.is_empty():
		return ""
	return "[E] " + ROOMS[door].enter if active.is_empty() else ("[E] Выйти на палубу" if active == "ship" else "[E] Выйти наружу")

func title(at: Vector3) -> String:
	if active == "ship":
		return "РУБКА · %s" % ("КАЮТА" if at.z > .31 else "ШТУРВАЛ")
	if not active.is_empty():
		return ROOMS[active].title.to_upper()
	return "СТАРЫЙ СКЛАД" if warehouse_open else ""

func camera_focus(at: Vector3) -> Vector3:
	var center: Vector3 = SHED if warehouse_open else ROOMS[active].origin
	return center.lerp(at, .59) + Vector3.UP*.76

func zoom() -> float:
	return SHED_ZOOM if warehouse_open else ROOMS[active].zoom
