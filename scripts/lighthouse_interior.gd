extends Node3D
## An interior cell with walkable spiral collision and a camera-facing cutaway.
const MODEL = preload("res://assets/models/lighthouse/lighthouse_interior_v01.glb")
const ORIGIN := Vector3(190, 25, 0)
const OUTSIDE_DOOR := Vector3(-9, 1.1, -4.43)
const INSIDE_DOOR := Vector3(1.62, 0, -.49)
const PITCH := 3.24
const TURNS := 3
const TOP := PITCH * TURNS
const INNER := .54
const WALL := 2.38
const LANDING := 2.2
const LOOK_OFFSET := Vector3(5.8, 8.7, 7.9)
const ZOOM := 6.7

var active := false
var room_env: Environment
var model: Node3D
var walls: Array[Node3D] = []
var flights: Array[Node3D] = []
var sconces: Array[Node3D] = []
var lamps: Array[OmniLight3D] = []
var optic: Node3D
var rotor: Node3D
var deck: Node3D
var glow: Node3D
var beacon_light: OmniLight3D

static func polar(radius: float, angle: float, height: float) -> Vector3:
	return Vector3(cos(angle)*radius, height, sin(angle)*radius)

func _ready() -> void:
	position = ORIGIN
	hide()

func _build() -> void:
	model = MODEL.instantiate()
	add_child(model)
	for level in range(4):
		for sector in range(16):
			walls.append(model.find_child("Wall_%02d_%02d" % [level, sector], true, false))
	for i in range(36):
		flights.append(model.find_child("Flight_%02d" % i, true, false))
	for i in range(9):
		sconces.append(model.find_child("Lamp_%02d" % i, true, false))
		lamps.append(_lamp(polar(1.77, 1.52+i*TAU/3, PITCH*i/3+1.5), Color("fdb275"), 1.25, 3.9))
	optic = model.find_child("LanternOptic", true, false)
	rotor = model.find_child("LensRotor", true, false)
	deck = model.find_child("LanternDeck", true, false)
	glow = model.find_child("BeaconGlow", true, false)
	_lamp(Vector3(1.45, 1.65, -.78), Color("f6c28d"), .92, 3.35)
	_lamp(Vector3(1.75, TOP+2.1, .6), Color("a3c7c3"), .85, 4.9)
	beacon_light = _lamp(Vector3(0, TOP+1.72, 0), Color("ffc881"), 1.38, 4.7)

	room_env = Environment.new()
	room_env.background_mode = Environment.BG_COLOR
	room_env.background_color = Color("11191b")
	room_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room_env.ambient_light_color = Color("aebfbd")
	room_env.ambient_light_energy = .43

	var surfaces := PackedVector3Array()
	for i in range(72):
		var a := i*TAU/72
		var b := (i+1)*TAU/72
		_triangle(surfaces, Vector3.ZERO, polar(WALL,a,0), polar(WALL,b,0))
		_quad(surfaces, polar(WALL,a,-.3), polar(WALL,b,-.3), polar(WALL,b,TOP+2.65), polar(WALL,a,TOP+2.65))
	for i in range(144):
		var a := i*TAU/48
		var b := (i+1)*TAU/48
		var y := PITCH*i/48
		var next_y := PITCH*(i+1)/48
		_quad(surfaces, polar(INNER,a,y), polar(WALL,a,y), polar(WALL,b,next_y), polar(INNER,b,next_y))
		_quad(surfaces, polar(INNER,a,y), polar(INNER,b,next_y), polar(INNER,b,next_y+1.1), polar(INNER,a,y+1.1))
	for i in range(24):
		_triangle(surfaces, Vector3.UP*TOP, polar(WALL,i*LANDING/24,TOP), polar(WALL,(i+1)*LANDING/24,TOP))
	_quad(surfaces, Vector3.UP*TOP, polar(WALL,LANDING,TOP), polar(WALL,LANDING,TOP+1.1), Vector3.UP*(TOP+1.1))
	var body := StaticBody3D.new()
	body.name = "WalkableStairAndWalls"
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(surfaces)
	collision.shape = shape
	body.add_child(collision)

	var pedestal := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = .52
	cylinder.height = 1.8
	pedestal.shape = cylinder
	pedestal.position.y = TOP+.9
	body.add_child(pedestal)
	_prop_collision(body, Vector3(-.82,.59,-1.56), Vector3(1.24,1.18,.43), -.18)
	_prop_collision(body, Vector3(-1.33,.23,-.94), Vector3(.5,.46,.46), .15)
	_prop_collision(body, Vector3(.05,TOP+.65,.83), Vector3(.47,1.3,.37), 0)

func _prop_collision(body: StaticBody3D, at: Vector3, size: Vector3, yaw: float) -> void:
	var prop := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	prop.shape = shape
	prop.position = at
	prop.rotation.y = yaw
	body.add_child(prop)

func _triangle(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	faces.append(a)
	faces.append(b)
	faces.append(c)

func _quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(faces, a,b,c)
	_triangle(faces, a,c,d)

func _lamp(at: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	add_child(light)
	return light

func contains(at: Vector3) -> bool:
	var local := at - ORIGIN
	return local.y >= -.28 and local.y <= TOP+2 and Vector2(local.x,local.z).length() < WALL

func near_door(at: Vector3) -> bool:
	var door := ORIGIN + INSIDE_DOOR if active else OUTSIDE_DOOR
	return absf(at.y-door.y) < .43 and Vector2(at.x-door.x, at.z-door.z).length() < (0.75 if active else 1.24)

func near_optic(at: Vector3) -> bool:
	var local := at - ORIGIN
	return local.y > TOP-.18 and Vector2(local.x, local.z).length() < 1.65

func prompt(at: Vector3) -> String:
	if near_door(at):
		return "[E] Выйти из маяка" if active else "[E] Войти в маяк"
	if not active:
		return ""
	if near_optic(at):
		return "[E] Осмотреть линзу"
	if at.y > ORIGIN.y+TOP-.18:
		return "МАЯК · фонарная"
	var turn := clampi(ceili((at.y-ORIGIN.y+.01)/PITCH), 1, TURNS)
	return "МАЯК · винтовая лестница   ↑   %d / %d" % [turn, TURNS]

func set_active(value: bool) -> void:
	if value and model == null:
		_build()
	active = value
	visible = value

func update_cutaway(at: Vector3, powered: bool, beam_angle: float) -> void:
	var height := at.y - ORIGIN.y
	var view_side := Vector2(LOOK_OFFSET.x, LOOK_OFFSET.z).normalized()
	for i in walls.size():
		var angle := (i%16+.5)*TAU/16
		var toward_camera := Vector2(cos(angle), sin(angle)).dot(view_side) > -.10
		walls[i].visible = not toward_camera and floori(i/16.0)*PITCH <= height+1.35
	for i in flights.size():
		flights[i].visible = i*PITCH/12 <= height+1.65
	for i in sconces.size():
		var angle := 1.52+i*TAU/3
		lamps[i].visible = i*PITCH/3 <= height+1.05
		sconces[i].visible = lamps[i].visible and Vector2(cos(angle),sin(angle)).dot(view_side) <= -.10
	deck.visible = height >= TOP-.44
	optic.visible = deck.visible
	rotor.visible = deck.visible
	if powered:
		rotor.rotation.y = beam_angle
	glow.visible = deck.visible and powered
	beacon_light.visible = glow.visible
