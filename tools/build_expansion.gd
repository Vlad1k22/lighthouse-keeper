extends SceneTree
## Generates an editable northern peninsula and a walkable coastal vessel.
const G = preload("res://scripts/geometry.gd")
const N = preload("res://scripts/natural_geometry.gd")
const STATION = preload("res://scripts/interactable.gd")
const OVERHAUL = preload("res://scripts/visual_overhaul.gd")
var land: Node3D
var wood := Color("645642")
var iron := Color("434c4d")

func _initialize() -> void:
	land = Node3D.new()
	land.name = "NorthernCoast"
	terrain()
	warehouse()
	radio_station()
	well()
	wreck()
	port()
	ship()
	paths_and_forest()
	station("board", "Доска задач и карта острова", Vector3(3.5, 1, -13))
	G.box(land, "NoticeBoard", Vector3(3.5, 2.1, -13.5), Vector3(2, 1.4, 0.15), wood)
	for x in [2.7, 4.3]:
		G.box(land, "BoardPost", Vector3(x, 1.7, -13.5), Vector3(0.12, 1.5, 0.14), wood, true)
	for x in [3.0, 3.65]:
		G.box(land, "Paper", Vector3(x, 2.2, -13.4), Vector3(0.5, 0.65, 0.02), Color("b3ad8a"))
	road_sign("СЕВЕРНЫЙ БЕРЕГ", Vector3(-1, 1, -17), "← ГАВАНЬ    СКЛАД →")
	OVERHAUL.apply(land)
	finish_materials()
	preload("res://scripts/ship_visual.gd").install(land.get_node("CoastalVessel"))
	preload("res://scripts/radio_visual.gd").install(land)
	own(land, land)
	var packed := PackedScene.new()
	packed.pack(land)
	var result := ResourceSaver.save(packed, "res://scenes/northern_coast.tscn")
	print("Northern coast saved: ", result)
	land.free()
	quit(result)

func own(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		if child.name != "BlenderVisual":
			own(child, root_node)

func finish_materials() -> void:
	# Assign the new props by their actual construction material.
	var timber := ["WarehouseBack","WarehouseSide","WarehouseFront","NoticeBoard","BoardPost","SignPost","SignBoard","WellPost","WellRoof","Firewood","HarborFoundation","PierPlank","ShipGangplank","ToolTable","BrokenHull","WreckRib","HelmWheel","WheelSpoke"]
	var metal := ["WheelhouseRoof","RadioRoof","CorrugatedRoof","RadioConsole","RadioDial","RadioKnob","AntennaMast","AntennaCross","GuyWire","RailStanchion","ShipRail","PortRail","SternRail","BowRail","ExhaustStack","ShipMast","MastSpar","HelmPedestal","ShipFuelTank","EngineHatch","CrabTrap","TrapBars","RedToolbox","SalvageBattery","MedicalCabinet","PumpBody","PumpHandle"]
	for node in land.find_children("*","MeshInstance3D",true,false):
		if not node.material_override is ShaderMaterial: continue
		var kind := -1
		for prefix in timber:
			if str(node.name).begins_with(prefix): kind=1
		for prefix in metal:
			if str(node.name).begins_with(prefix): kind=6
		if str(node.name)=="Wheelhouse" or str(node.name)=="RadioHut": kind=2
		if kind>=0:
			var color: Color = node.material_override.get_shader_parameter("base_color")
			node.material_override = N.surface(color,kind)

func terrain() -> void:
	var boundary := PackedVector3Array()
	for i in 80:
		var a := TAU * i / 80.0
		var wobble := 1.0 + sin(a * 7) * 0.028 + cos(a * 5) * 0.025
		boundary.append(Vector3(-4 + cos(a)*23*wobble, 1, -28 + sin(a)*20*wobble))
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision := PackedVector3Array()
	for i in boundary.size():
		var a := boundary[i]
		var b := boundary[(i+1)%boundary.size()]
		for v in [Vector3(-4,1,-28), b, a]:
			top.add_vertex(v)
		var low_a := Vector3(a.x, -0.9, a.z)
		var low_b := Vector3(b.x, -0.9, b.z)
		for v in [a,b,low_a,b,low_b,low_a]:
			cliff.add_vertex(v)
		collision.append(a)
		collision.append(low_a)
	N.mesh_node(land, "NorthernSoil", top, N.surface(Color("4f5546"),4))
	N.mesh_node(land, "NorthernCliffs", cliff, N.surface(Color("555c56"),0))
	var body := StaticBody3D.new()
	body.name = "PeninsulaCollision"
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = collision
	shape.shape = convex
	body.add_child(shape)
	land.add_child(body)

func warehouse() -> void:
	var at := Vector3(7,1,-31)
	G.box(land,"WarehouseBack",at+Vector3(0,1.65,-3),Vector3(8,3.3,0.18),wood,true)
	for x in [-4.0,4.0]:
		G.box(land,"WarehouseSide",at+Vector3(x,1.65,0),Vector3(0.18,3.3,6),wood,true)
	for x in [-2.8,2.8]:
		G.box(land,"WarehouseFront",at+Vector3(x,1.65,3),Vector3(2.4,3.3,0.18),wood,true)
	for side in [-1,1]:
		var roof := G.box(land,"CorrugatedRoof",at+Vector3(side*2.1,3.65,0),Vector3(4.5,0.12,6.7),iron)
		roof.rotation.z = side * -0.16
	for i in 4:
		G.crate(land,at+Vector3(-2.8+(i%2)*1.3,0,-1+(i/2)*1.2),1.0)
	G.box(land,"ToolTable",Vector3(9,1.9,-33),Vector3(2,0.16,0.9),wood,true)
	G.box(land,"RedToolbox",Vector3(9,2.15,-33),Vector3(0.9,0.42,0.45),Color("6e3e32"))
	station("tools","Забрать инструменты · день 2",Vector3(9,1,-32))
	station("scrap","Склад · детали +2 раз в день",Vector3(7,1,-31.2))
	G.box(land,"MedicalCabinet",Vector3(10.8,2,-29.6),Vector3(0.2,0.8,0.6),Color("a5aba0"))
	G.box(land,"MedicalCross",Vector3(10.65,2,-29.6),Vector3(0.03,0.42,0.12),Color("86463b"))
	station("medical","Аптечка · раз в день",Vector3(10,1,-29.4))
	road_sign("СТАРЫЙ СКЛАД",Vector3(3.4,1,-27.2),"Инструменты / детали / аптечка")

func radio_station() -> void:
	G.box(land,"RadioHut",Vector3(-12,2.15,-39.5),Vector3(5,2.3,3.7),Color("65645a"),true)
	G.box(land,"RadioRoof",Vector3(-12,3.4,-39.5),Vector3(5.5,0.18,4.2),iron)
	G.box(land,"RadioConsole",Vector3(-12,1.65,-36.7),Vector3(1.9,1.3,0.7),iron,true)
	G.box(land,"RadioDial",Vector3(-12,2,-36.3),Vector3(1.3,0.24,0.03),Color("68705a"))
	for x in [-12.6,-11.4]:
		G.cylinder(land,"RadioKnob",Vector3(x,1.6,-36.3),0.1,0.12,Color("b2a884"))
	G.cylinder(land,"AntennaMast",Vector3(-16,5.5,-40),0.12,9,iron,0.05,true)
	for y in [6,8,9.5]:
		G.line(land,"AntennaCross",Vector3(-18,y,-40),Vector3(-14,y,-40),0.04,iron)
	for p in [Vector3(-19,1,-42),Vector3(-14,1,-44),Vector3(-17,1,-36)]:
		G.line(land,"GuyWire",Vector3(-16,8,-40),p,0.012,iron)
	station("transmitter","Починить передатчик · день 4",Vector3(-12,1,-35.9))
	road_sign("РАДИОСТАНЦИЯ",Vector3(-8,1,-35),"Частота спасателей 104.6")

func well() -> void:
	G.cylinder(land,"WellStone",Vector3(0,1.45,-23),1.0,0.9,Color("747769"),0.85,true)
	G.cylinder(land,"WellDark",Vector3(0,1.92,-23),0.65,0.03,Color("142327"))
	for x in [-1.1,1.1]:
		G.box(land,"WellPost",Vector3(x,2.3,-23),Vector3(0.15,2.6,0.15),wood,true)
	G.box(land,"WellRoof",Vector3(0,3.7,-23),Vector3(3,0.17,2.3),wood)
	G.box(land,"PumpBody",Vector3(1.5,1.5,-23),Vector3(0.4,1,0.4),Color("365c56"),true)
	G.line(land,"PumpHandle",Vector3(1.5,2.1,-23),Vector3(2,2.2,-23),0.06,iron)
	station("pump","Насос колодца · день 3",Vector3(1.5,1,-21.7))
	G.barrel(land,Vector3(-2,1,-23))

func wreck() -> void:
	var center := Vector3(11,1,-41)
	for i in 8:
		var rib := G.box(land,"WreckRib",center+Vector3((i%2)*2-1,0.7,(i/2)*0.9),Vector3(0.13,1.4,0.18),wood)
		rib.rotation.z = -0.3 if i%2==0 else 0.3
	for x in [-1.4,1.4]:
		G.box(land,"BrokenHull",center+Vector3(x,0.3,1.2),Vector3(0.15,0.55,4.5),wood)
	G.box(land,"SalvageBattery",center+Vector3(0,0.25,1),Vector3(0.65,0.5,0.5),iron)
	station("battery","Остов лодки · аккумулятор",Vector3(11,1,-39))
	road_sign("ОСТОВ ЛОДКИ",Vector3(14,1,-38),"Высадка запрещена. 30 октября.")

func port() -> void:
	G.box(land,"HarborFoundation",Vector3(-24.5,0.7,-21),Vector3(11,0.6,3.4),wood,true)
	for i in 28:
		G.box(land,"PierPlank",Vector3(-29.75+i*0.4,0.97,-21),Vector3(0.38,0.06,3.3),wood)
	for x in [-28,-25,-22,-20]:
		for z in [-22.5,-19.5]:
			G.cylinder(land,"HarborPile",Vector3(x,0.25,z),0.16,2.4,wood,0.12,true)
	G.box(land,"ShipGangplank",Vector3(-30,0.86,-21),Vector3(5.2,0.28,2.2),wood,true)
	for z in [-22.15,-19.85]:
		G.line(land,"GangplankRope",Vector3(-32.2,1.8,z),Vector3(-27.7,1.8,z),0.025,Color("9b9676"))
	for i in 4:
		G.barrel(land,Vector3(-21+(i%2)*1.2,1,-24-(i/2)*1.2))
	station("depot","Бочка топлива · +2 раз в день",Vector3(-20.5,1,-23))
	G.crate(land,Vector3(-19,1,-27),1.2)
	station("cache","Тайник · два сухпайка",Vector3(-18.5,1,-26))
	station("trap","Краболовка · наживка / улов",Vector3(-25,1,-19.8))
	G.box(land,"CrabTrap",Vector3(-25,0.75,-18.7),Vector3(1.2,0.7,0.8),iron)
	for i in 6:
		G.box(land,"TrapBars",Vector3(-25.5+i*0.2,1.12,-18.7),Vector3(0.025,0.03,0.85),Color("8c9183"))
	road_sign("СТАРАЯ ГАВАНЬ",Vector3(-18,1,-19),"← Катер «Северный»")
	G.cylinder(land,"CampfireStones",Vector3(-16,1.07,-28),0.85,0.14,Color("777766"))
	for i in 5:
		G.line(land,"Firewood",Vector3(-16.5,1.2,-28+i*0.15),Vector3(-15.5,1.25,-27.8+i*0.1),0.08,wood)
	var fire := OmniLight3D.new()
	fire.name = "HarborFire"
	fire.position = Vector3(-16,2,-28)
	fire.omni_range = 8
	fire.light_color = Color("e8a365")
	fire.light_energy = 0
	land.add_child(fire)
	var embers := CPUParticles3D.new()
	embers.name = "HarborEmbers"
	embers.position = Vector3(-16,1.3,-28)
	embers.amount = 20
	embers.lifetime = 1.5
	embers.emitting = false
	embers.direction = Vector3.UP
	embers.spread = 20
	embers.gravity = Vector3(0,0.4,0)
	embers.initial_velocity_min = 0.2
	embers.initial_velocity_max = 0.7
	embers.scale_amount_min = 0.025
	embers.scale_amount_max = 0.07
	embers.mesh = SphereMesh.new()
	embers.material_override = G.material(Color("db8d41"),2)
	land.add_child(embers)
	station("fire","Костёр · 1 древесина на ночь",Vector3(-16,1,-26.7))

func ship() -> void:
	var root_ship := Node3D.new()
	root_ship.name = "CoastalVessel"
	root_ship.position = Vector3(-33,0,-24)
	land.add_child(root_ship)
	var outline := [Vector2(-3.3,7.8),Vector2(3.3,7.8),Vector2(3.5,-5.5),Vector2(2.4,-8),Vector2(0,-10),Vector2(-2.4,-8),Vector2(-3.5,-5.5)]
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		for v in [Vector3(a.x,0.85,a.y),Vector3(a.x*0.65,-0.7,a.y*0.92),Vector3(b.x,0.85,b.y),Vector3(b.x,0.85,b.y),Vector3(a.x*0.65,-0.7,a.y*0.92),Vector3(b.x*0.65,-0.7,b.y*0.92)]:
			hull.add_vertex(v)
	N.mesh_node(root_ship,"RustedHull",hull,N.surface(Color("583d36"),6))
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	for i in outline.size():
		var a: Vector2 = outline[i]*0.98
		var b: Vector2 = outline[(i+1)%outline.size()]*0.98
		for v in [Vector3(0,1,0),Vector3(a.x,1,a.y),Vector3(b.x,1,b.y)]: deck.add_vertex(v)
		points.append(Vector3(a.x,1,a.y))
		points.append(Vector3(a.x,0.6,a.y))
	var deck_mesh := N.mesh_node(root_ship,"WalkableDeck",deck,N.surface(wood,1))
	var deck_shape := ConvexPolygonShape3D.new()
	deck_shape.points = points
	G.collider(deck_mesh,deck_shape)
	for i in 20:
		var z := -8.5+i*0.82
		G.box(root_ship,"DeckSeam",Vector3(0,1.005,z),Vector3(minf(6.4,(10+z)*2),0.012,0.024),Color("393b32"))
	for x in [-3.3,3.3]:
		for z in [-7.5,-4.5,-1.5,1.5,4.8,7.7]:
			if x>0 and z==4.8:
				continue
			G.cylinder(root_ship,"RailStanchion",Vector3(x,1.5,z),0.045,1.0,iron,0.045,true)
		for segment in [[-8.5,1.7],[4.4,7.8]]:
			G.box(root_ship,"ShipRail",Vector3(x,1.96,(segment[0]+segment[1])/2),Vector3(0.07,0.07,segment[1]-segment[0]),iron,true)
		if x<0:
			G.box(root_ship,"PortRail",Vector3(x,1.96,3),Vector3(0.07,0.07,2.6),iron,true)
	G.box(root_ship,"Wheelhouse",Vector3(0,2.05,-5.7),Vector3(4.2,2.1,3.6),Color("88897b"),true)
	G.box(root_ship,"WheelhouseRoof",Vector3(0,3.22,-5.7),Vector3(4.8,0.24,4.2),iron)
	for x in [-1.1,1.1]:
		G.box(root_ship,"WheelhouseGlass",Vector3(x,2.55,-3.88),Vector3(1.6,0.8,0.04),Color("253c3f"))
	G.cylinder(root_ship,"ExhaustStack",Vector3(0,4,-6),0.32,1.5,Color("383c39"))
	var wheel := MeshInstance3D.new()
	wheel.name = "HelmWheel"
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.28
	wheel_mesh.outer_radius = 0.34
	wheel.mesh = wheel_mesh
	wheel.position = Vector3(0,1.85,-3.4)
	wheel.rotation.x = PI/2
	wheel.material_override = N.surface(wood,1)
	root_ship.add_child(wheel)
	G.cylinder(root_ship,"HelmPedestal",Vector3(0,1.35,-3.4),0.12,0.7,iron)
	for i in 6:
		var a := TAU*i/6
		G.line(root_ship,"WheelSpoke",Vector3(0,1.85,-3.4),Vector3(cos(a)*0.37,1.85+sin(a)*0.37,-3.4),0.022,wood)
	var smoke := CPUParticles3D.new()
	smoke.name = "EngineSmoke"
	smoke.position = Vector3(0,4.75,-6)
	smoke.amount = 16
	smoke.lifetime = 3
	smoke.emitting = false
	smoke.direction = Vector3(0.2,1,0.3)
	smoke.gravity = Vector3(0.2,0.2,0.1)
	smoke.initial_velocity_min = 0.3
	smoke.initial_velocity_max = 0.6
	smoke.scale_amount_min = 0.18
	smoke.scale_amount_max = 0.4
	smoke.mesh = SphereMesh.new()
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.25,0.29,0.28,0.18)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = smoke_mat
	root_ship.add_child(smoke)
	var wake := CPUParticles3D.new()
	wake.name = "SailingWake"
	wake.position = Vector3(0,0.15,8)
	wake.local_coords = false
	wake.amount = 50
	wake.lifetime = 3
	wake.emitting = false
	wake.direction = Vector3(0,0,1)
	wake.spread = 35
	wake.gravity = Vector3.ZERO
	wake.initial_velocity_min = 0.8
	wake.initial_velocity_max = 2
	wake.scale_amount_min = 0.5
	wake.scale_amount_max = 1.4
	var wake_mesh := SphereMesh.new()
	wake_mesh.radius = 0.25
	wake_mesh.height = 0.04
	wake.mesh = wake_mesh
	var wake_mat := StandardMaterial3D.new()
	wake_mat.albedo_color = Color(0.55,0.63,0.57,0.25)
	wake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wake.material_override = wake_mat
	root_ship.add_child(wake)
	for x in [-1.5,1.5]:
		var ring := MeshInstance3D.new()
		ring.name = "Lifebuoy"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.25
		torus.outer_radius = 0.4
		ring.mesh = torus
		ring.position = Vector3(x,1.8,7.6)
		ring.rotation.x = PI/2
		ring.material_override = N.surface(Color("a87143"),3)
		root_ship.add_child(ring)
	G.box(root_ship,"SternRail",Vector3(0,1.9,7.7),Vector3(6.5,0.07,0.07),iron,true)
	G.box(root_ship,"BowRail",Vector3(0,1.9,-9.5),Vector3(1.4,0.07,0.07),iron,true)
	G.cylinder(root_ship,"ShipMast",Vector3(0,4.9,-2.8),0.07,7.8,iron)
	G.line(root_ship,"MastSpar",Vector3(-2,7,-2.8),Vector3(2,7,-2.8),0.04,iron)
	G.box(root_ship,"EngineHatch",Vector3(0,1.1,1.0),Vector3(1.8,0.2,1.5),iron)
	G.box(root_ship,"HullDamage",Vector3(1.1,1.013,6.1),Vector3(1.7,0.012,1.2),Color("162222"))
	G.box(root_ship,"HullPatch",Vector3(1.1,1.03,6.1),Vector3(1.7,0.04,1.2),Color("8c7753"))
	for i in 2:
		G.crate(root_ship,Vector3(-2,1,3+i*1.4),0.85)
	G.cylinder(root_ship,"ShipFuelTank",Vector3(2,1.5,-0.9),0.45,1,Color("5a6556"),0.45,true)
	for z in [-6,6]:
		G.line(land,"MooringRope",Vector3(-29.7,1.35,-24+z),Vector3(-25,1.1,-21),0.025,Color("8c846d"))
	label(root_ship,"СЕВЕРНЫЙ",Vector3(0,2.35,-3.83),0.009)
	station("ship_hull","Корпус · 5 дерева + 2 детали",Vector3(-31.8,1,-18))
	station("ship_engine","Двигатель · 4 детали",Vector3(-33,1,-23))
	station("ship_fuel","Бак катера · 3 топлива",Vector3(-30.8,1,-25))
	station("ship_stores","Загрузить 3 готовых блюда",Vector3(-35,1,-20))
	station("ship_helm","Штурвал · выйти в море",Vector3(-33,1,-27.3))
	var ready_light := OmniLight3D.new()
	ready_light.name = "NavigationLight"
	ready_light.position = Vector3(0,4,-3.5)
	ready_light.light_color = Color("91b9a3")
	ready_light.omni_range = 8
	ready_light.light_energy = 0
	root_ship.add_child(ready_light)

func paths_and_forest() -> void:
	var routes := [[Vector3(0,1.015,-12),Vector3(0,1.015,-20)],[Vector3(0,1.015,-20),Vector3(-3,1.015,-25)],[Vector3(-3,1.015,-25),Vector3(0,1.015,-34)],[Vector3(-23,1.015,-21),Vector3(7,1.015,-28)],[Vector3(0,1.015,-34),Vector3(-12,1.015,-36)],[Vector3(0,1.015,-34),Vector3(11,1.015,-39)]]
	for route in routes:
		var middle: Vector3 = (route[0]+route[1])*0.5
		var road := G.box(land,"GravelPath",middle,Vector3(2.7,0.025,route[0].distance_to(route[1])),Color("65624f"))
		road.rotation.y = atan2(route[1].x-route[0].x,route[1].z-route[0].z)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2631
	for i in 100:
		var at := Vector3(rng.randf_range(-25,18),1,rng.randf_range(-46,-13))
		if Vector2((at.x+4)/21,(at.z+28)/18).length()>1:
			continue
		var near_road := false
		for route in routes:
			if Geometry3D.get_closest_point_to_segment(at,route[0],route[1]).distance_to(at)<3:
				near_road = true
		for place in [Vector3(7,1,-31),Vector3(-12,1,-39),Vector3(11,1,-41),Vector3(-19,1,-24),Vector3(0,1,-23)]:
			if place.distance_to(at)<6:
				near_road = true
		if not near_road:
			G.tree(land,at,rng.randf_range(1.6,2.6),0)
	for i in 70:
		var a := TAU*i/70.0
		var at := Vector3(-4+cos(a)*23,0.2,-28+sin(a)*20)
		if at.distance_to(Vector3(-25,0.2,-21))<7:
			continue
		G.rock(land,at,Vector3(rng.randf_range(0.6,1.9),1.5,rng.randf_range(0.7,2)),Color("59615a"),a)
	for at in [Vector3(-6,1,-28),Vector3(14,1,-22),Vector3(-8,1,-43)]:
		G.box(land,"FallenTimber",at+Vector3(0,0.2,0),Vector3(3,0.4,0.5),wood)
	station("north_wood","Северный валежник · +2 дерева",Vector3(-6,1,-26.8))

func label(parent: Node3D, title: String, at: Vector3, pixels: float) -> void:
	var node := Label3D.new()
	node.text = title
	node.position = at
	node.font_size = 48
	node.pixel_size = pixels
	node.modulate = Color("c6bea0")
	parent.add_child(node)

func road_sign(title: String, at: Vector3, subtitle: String) -> void:
	G.box(land,"SignPost",at+Vector3(0,0.7,0),Vector3(0.12,1.4,0.14),wood,true)
	G.box(land,"SignBoard",at+Vector3(0,1.5,0),Vector3(3,0.85,0.12),wood)
	label(land,title,at+Vector3(0,1.65,0.07),0.009)
	label(land,subtitle,at+Vector3(0,1.33,0.07),0.0045)

func station(id: String, title: String, at: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Station_"+id
	area.set_script(STATION)
	area.station_id = id
	area.display_name = title
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 2
	land.add_child(area)
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 2.4
	shape.shape = ball
	area.add_child(shape)
	var marker := Label3D.new()
	marker.name = "InteractionMarker"
	marker.text = "◆"
	marker.font_size = 38
	marker.pixel_size = 0.014
	marker.position.y = 2.3
	marker.modulate = Color("d2b57c")
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(marker)
	var ring := MeshInstance3D.new()
	ring.name = "SelectionRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.64
	mesh.outer_radius = 0.69
	ring.mesh = mesh
	ring.position.y = 0.08
	ring.material_override = G.material(Color("d2b57c"),0.4)
	ring.visible = false
	area.add_child(ring)
