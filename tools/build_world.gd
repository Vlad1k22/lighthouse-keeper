extends SceneTree
## Генератор авторской геометрии. Результат — обычная редактируемая world.tscn.

const Geo = preload("res://scripts/geometry.gd")
const STATION = preload("res://scripts/interactable.gd")
const BEACON = preload("res://scripts/beacon.gd")
const PLAYER = preload("res://scripts/player.gd")
const SHADOW = preload("res://scripts/shadow.gd")
var rng := RandomNumberGenerator.new()
var world: Node3D
var land: Node3D

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	rng.seed = 112026
	world = Node3D.new()
	world.name = "CoastalIsland"
	root.add_child(world)
	land = Node3D.new()
	land.name = "IslandGeometry"
	world.add_child(land)
	make_terrain()
	make_lighthouse(Vector3(-9, 1, -7))
	make_cabin(Vector3(5, 1, 0))
	make_dock()
	make_forest()
	make_paths()
	make_props()
	make_lighting()
	make_characters()
	set_owners(world, world)
	var packed := PackedScene.new()
	var result := packed.pack(world)
	if result == OK:
		result = ResourceSaver.save(packed, "res://scenes/world.tscn")
	print("World scene saved: ", result, "; nodes: ", world.find_children("*", "", true, false).size())
	quit(0 if result == OK else 1)

func make_characters() -> void:
	var player := CharacterBody3D.new()
	player.name = "Keeper"
	player.set_script(PLAYER)
	player.collision_layer = 2
	player.collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	player.add_child(collision)
	var visual := Node3D.new()
	visual.name = "Visual"
	player.add_child(visual)
	Geo.cylinder(visual, "OilskinCoat", Vector3(0, 0.95, 0), 0.28, 0.8, Color("d2a34e"), 0.23)
	Geo.sphere(visual, "Head", Vector3(0, 1.52, 0), Vector3(0.38, 0.43, 0.36), Color("cfb18d"))
	for side in [-1, 1]:
		Geo.box(visual, "Eye", Vector3(side * 0.075, 1.54, 0.172), Vector3(0.035, 0.04, 0.015), Color("34464a"))
	Geo.sphere(visual, "Nose", Vector3(0, 1.49, 0.19), Vector3(0.07, 0.075, 0.08), Color("c2a17d"))
	Geo.cylinder(visual, "WoolCap", Vector3(0, 1.72, 0), 0.22, 0.15, Color("33484c"), 0.16)
	Geo.box(visual, "Collar", Vector3(0, 1.29, 0.03), Vector3(0.4, 0.12, 0.32), Color("957344"))
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LeftLeg" if side == -1 else "RightLeg"
		leg.position = Vector3(side * 0.13, 0.6, 0)
		visual.add_child(leg)
		Geo.box(leg, "Trousers", Vector3(0, -0.2, 0), Vector3(0.18, 0.45, 0.2), Color("33484d"))
		Geo.box(leg, "Boot", Vector3(0, -0.5, 0.06), Vector3(0.21, 0.2, 0.32), Color("28393e"))
		var arm := Node3D.new()
		arm.name = "LeftArm" if side == -1 else "RightArm"
		arm.position = Vector3(side * 0.3, 1.2, 0)
		visual.add_child(arm)
		Geo.cylinder(arm, "Sleeve", Vector3(0, -0.2, 0), 0.1, 0.45, Color("bd8f40"))
		Geo.sphere(arm, "Hand", Vector3(0, -0.43, 0), Vector3(0.15, 0.17, 0.16), Color("c7a784"))
	Geo.box(visual, "Satchel", Vector3(0, 1, -0.25), Vector3(0.35, 0.45, 0.2), Color("645642"))
	Geo.cylinder(visual, "LanternCage", Vector3(0.4, 0.59, 0.07), 0.11, 0.23, Color("efc073"), -1, false, 1.0)
	var lamp := OmniLight3D.new()
	lamp.name = "HandLantern"
	lamp.position = Vector3(0, 1.2, 0.2)
	lamp.light_color = Color("ffcd8a")
	lamp.light_energy = 1.2
	lamp.omni_range = 6
	player.add_child(lamp)
	var animator := AnimationPlayer.new()
	animator.name = "WalkAnimation"
	var walk := Animation.new()
	walk.length = 0.8
	walk.loop_mode = Animation.LOOP_LINEAR
	var limbs := ["LeftLeg", "RightLeg", "LeftArm", "RightArm"]
	for index in limbs.size():
		var track := walk.add_track(Animation.TYPE_VALUE)
		walk.track_set_path(track, NodePath("Visual/" + limbs[index] + ":rotation:x"))
		var amplitude := (0.55 if index < 2 else 0.32) * (-1 if index % 2 == 1 else 1)
		for key in 5:
			walk.track_insert_key(track, key * 0.2, sin(key * PI * 0.5) * amplitude)
	var library := AnimationLibrary.new()
	library.add_animation("walk", walk)
	animator.add_animation_library("", library)
	player.add_child(animator)
	save_character(player, "res://scenes/keeper.tscn")
	var shadow := CharacterBody3D.new()
	shadow.name = "NightShadow"
	shadow.set_script(SHADOW)
	shadow.collision_layer = 4
	shadow.collision_mask = 1
	var shadow_collision := CollisionShape3D.new()
	shadow_collision.shape = capsule
	shadow_collision.position.y = 0.85
	shadow.add_child(shadow_collision)
	var shadow_visual := Node3D.new()
	shadow_visual.name = "Visual"
	shadow.add_child(shadow_visual)
	Geo.cylinder(shadow_visual, "Silhouette", Vector3(0, 0.9, 0), 0.34, 1.8, Color("152c32"), 0.14)
	Geo.sphere(shadow_visual, "Head", Vector3(0, 1.93, 0), Vector3(0.36, 0.48, 0.34), Color("152c32"))
	for side in [-1, 1]:
		Geo.line(shadow_visual, "Arm", Vector3(side * 0.21, 1.3, 0), Vector3(side * 0.5, 0.35, 0.1), 0.06, Color("152c32"))
		Geo.box(shadow_visual, "Eye", Vector3(side * 0.08, 1.99, 0.15), Vector3(0.045, 0.035, 0.03), Color("b9d4be"), false, 1.0)
	save_character(shadow, "res://scenes/shadow.tscn")

func save_character(character: Node3D, path_name: String) -> void:
	set_owners(character, character)
	var packed := PackedScene.new()
	packed.pack(character)
	ResourceSaver.save(packed, path_name)
	character.free()

func set_owners(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		set_owners(child, owner_node)

func edge(angle: float, radius_x: float, radius_z: float) -> Vector3:
	var offset := 1.0 + 0.045 * sin(angle * 5.0) + 0.035 * cos(angle * 7.0)
	return Vector3(cos(angle) * radius_x * offset, 1.0, sin(angle) * radius_z * offset)

func make_terrain() -> void:
	var water := MeshInstance3D.new()
	water.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	plane.subdivide_width = 60
	plane.subdivide_depth = 60
	water.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	water.material_override = mat
	world.add_child(water)
	var sand_verts := PackedVector3Array()
	var sand_colors := PackedColorArray()
	var grass_verts := PackedVector3Array()
	var grass_colors := PackedColorArray()
	var cliffs := PackedVector3Array()
	var cliff_colors := PackedColorArray()
	var collision_points := PackedVector3Array()
	for index in 72:
		var a := TAU * index / 72.0
		var b := TAU * (index + 1) / 72.0
		var outer_a := edge(a, 21.5, 17.5)
		var outer_b := edge(b, 21.5, 17.5)
		var inner_a := edge(a, 18.9, 14.7) + Vector3(0, 0.035, 0)
		var inner_b := edge(b, 18.9, 14.7) + Vector3(0, 0.035, 0)
		append_triangle(sand_verts, sand_colors, Vector3(0, 1, 0), outer_b, outer_a, Color("89846a").lightened(rng.randf_range(-0.04, 0.04)))
		append_triangle(grass_verts, grass_colors, Vector3(0, 1.035, 0), inner_b, inner_a, Color("4d6556").lightened(rng.randf_range(-0.025, 0.025)))
		var low_a := Vector3(outer_a.x * 1.025, -0.8, outer_a.z * 1.025)
		var low_b := Vector3(outer_b.x * 1.025, -0.8, outer_b.z * 1.025)
		append_triangle(cliffs, cliff_colors, outer_a, outer_b, low_a, Color("59656a").lightened(rng.randf_range(-0.06, 0.06)))
		append_triangle(cliffs, cliff_colors, outer_b, low_b, low_a, Color("46545b"))
		collision_points.append(outer_a)
		collision_points.append(low_a)
		if index % 3 == 0:
			var stone_pos := outer_a * Vector3(1.02, 0, 1.02)
			stone_pos.y = 0.35
			Geo.rock(land, stone_pos, Vector3(rng.randf_range(1.4, 3.0), 1.5, rng.randf_range(1.2, 2.6)), Color("59666c"), a)
	Geo.triangle_surface(land, "SandShore", sand_verts, sand_colors)
	Geo.triangle_surface(land, "Grassland", grass_verts, grass_colors)
	Geo.triangle_surface(land, "Cliffs", cliffs, cliff_colors)
	var shape := ConvexPolygonShape3D.new()
	shape.points = collision_points
	Geo.collider(land, shape)
	for index in 36:
		var a := TAU * index / 36.0
		var pos := edge(a, 23.1, 18.8)
		pos.y = 0.035
		var foam := Geo.box(world, "SeaFoam", pos, Vector3(rng.randf_range(1.0, 2.7), 0.025, 0.13), Color("a4c5c2"))
		foam.rotation.y = -a + PI * 0.5

func append_triangle(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	verts.append_array(PackedVector3Array([a, b, c]))
	colors.append_array(PackedColorArray([color, color, color]))

func make_lighthouse(at: Vector3) -> void:
	var lighthouse := Node3D.new()
	lighthouse.name = "Lighthouse"
	lighthouse.position = at
	lighthouse.set_script(BEACON)
	land.add_child(lighthouse)
	Geo.cylinder(lighthouse, "Foundation", Vector3(0, 0.2, 0), 2.1, 0.4, Color("8b8b7d"), -1, true)
	for index in 5:
		var color := Color("d4cab2") if index % 2 == 0 else Color("9c5344")
		Geo.cylinder(lighthouse, "TowerBand", Vector3(0, 1.4 + index * 1.8, 0), 1.5 - index * 0.12, 1.8, color, 1.38 - index * 0.12, true)
	Geo.box(lighthouse, "OakDoor", Vector3(0.3, 1.1, 1.49), Vector3(0.8, 1.8, 0.14), Color("3e4e4e"))
	Geo.box(lighthouse, "DoorFrame", Vector3(0.3, 2.08, 1.5), Vector3(1.0, 0.12, 0.2), Color("c9bea2"))
	for index in 4:
		Geo.box(lighthouse, "Window", Vector3(0, 3.0 + index * 1.5, 1.42 - index * 0.1), Vector3(0.28, 0.55, 0.08), Color("293b46"))
	Geo.cylinder(lighthouse, "BalconyFloor", Vector3(0, 9.7, 0), 1.9, 0.22, Color("39484b"))
	for index in 16:
		var a := TAU * index / 16.0
		var b := TAU * (index + 1) / 16.0
		Geo.cylinder(lighthouse, "BalconyPost", Vector3(cos(a) * 1.7, 10.2, sin(a) * 1.7), 0.035, 0.9, Color("39484b"))
		Geo.line(lighthouse, "Handrail", Vector3(cos(a) * 1.7, 10.62, sin(a) * 1.7), Vector3(cos(b) * 1.7, 10.62, sin(b) * 1.7), 0.04, Color("39484b"))
	Geo.cylinder(lighthouse, "LanternGlass", Vector3(0, 10.65, 0), 1.05, 1.7, Color("e7bc70"), -1, false, 0.7)
	for index in 8:
		var a := TAU * index / 8.0
		Geo.cylinder(lighthouse, "LanternFrame", Vector3(cos(a) * 1.08, 10.65, sin(a) * 1.08), 0.05, 1.8, Color("34484b"))
	Geo.cylinder(lighthouse, "CopperRoof", Vector3(0, 11.9, 0), 1.55, 0.9, Color("355552"), 0)
	Geo.cylinder(lighthouse, "Finial", Vector3(0, 12.65, 0), 0.08, 0.8, Color("34484b"), 0.01)
	var lantern := OmniLight3D.new()
	lantern.name = "Lantern"
	lantern.position.y = 10.6
	lantern.light_color = Color("ffd494")
	lantern.light_energy = 3.5
	lantern.omni_range = 12
	lighthouse.add_child(lantern)
	var pivot := Node3D.new()
	pivot.name = "BeamPivot"
	pivot.position.y = 10.7
	lighthouse.add_child(pivot)
	var beam := Geo.cylinder(pivot, "VisibleBeam", Vector3(0, 0, 12), 3.5, 24, Color("ffe5ae"), 0.04)
	beam.rotation_degrees.x = -90
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(1.0, 0.8, 0.45, 0.085)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spot := SpotLight3D.new()
	spot.name = "RotatingBeaconLight"
	spot.rotation_degrees = Vector3(-8, 180, 0)
	spot.light_color = Color("ffe3ac")
	spot.light_energy = 8
	spot.spot_range = 42
	spot.spot_angle = 17
	pivot.add_child(spot)
	Geo.box(land, "Generator", at + Vector3(2.6, 0.5, 0.5), Vector3(1.2, 1, 0.8), Color("4e6058"), true)
	Geo.cylinder(land, "GeneratorExhaust", at + Vector3(2.6, 1.2, 0.4), 0.1, 0.5, Color("344246"))
	station("beacon", "Генератор маяка", at + Vector3(2.6, 0, 1.5))
	add_lamp(at + Vector3(1.7, 0, 2.5))

func make_cabin(at: Vector3) -> void:
	var cabin := Node3D.new()
	cabin.name = "KeeperCabin"
	cabin.position = at
	land.add_child(cabin)
	Geo.box(cabin, "StoneBase", Vector3(0, 0.2, 0), Vector3(6.1, 0.4, 4.7), Color("63716e"), true)
	Geo.box(cabin, "TimberWalls", Vector3(0, 1.6, 0), Vector3(5.7, 2.8, 4.2), Color("6c7c70"), true)
	for index in 14:
		Geo.box(cabin, "FrontCladding", Vector3(-2.67 + index * 0.41, 1.6, 2.12), Vector3(0.05, 2.6, 0.06), Color("4d625c"))
	for x in [-2.8, 2.8]:
		Geo.box(cabin, "CornerBeam", Vector3(x, 1.6, 2.15), Vector3(0.17, 2.9, 0.17), Color("c2b28d"))
	Geo.box(cabin, "Door", Vector3(0, 1.25, 2.18), Vector3(0.95, 2.1, 0.12), Color("354a4c"))
	Geo.box(cabin, "DoorGlass", Vector3(0, 1.65, 2.26), Vector3(0.48, 0.65, 0.05), Color("edba72"), false, 0.8)
	for x in [-1.72, 1.72]:
		Geo.box(cabin, "WindowFrame", Vector3(x, 1.65, 2.19), Vector3(1.04, 1.0, 0.15), Color("c2b28d"))
		Geo.box(cabin, "WarmWindow", Vector3(x, 1.65, 2.29), Vector3(0.85, 0.82, 0.05), Color("e6b46d"), false, 1.1)
		Geo.box(cabin, "WindowMullion", Vector3(x, 1.65, 2.33), Vector3(0.07, 0.85, 0.04), Color("524e3d"))
		Geo.box(cabin, "WindowMullion", Vector3(x, 1.65, 2.33), Vector3(0.85, 0.07, 0.04), Color("524e3d"))
	var roof_color := Color("42575c")
	for side in [-1.0, 1.0]:
		var roof := Geo.box(cabin, "PitchedRoof", Vector3(0, 3.5, side * 1.15), Vector3(6.7, 0.18, 2.75), roof_color)
		roof.rotation.x = side * deg_to_rad(29)
		for stripe in 12:
			var seam := Geo.box(cabin, "RoofSeam", Vector3(-3.1 + stripe * 0.55, 3.61, side * 1.15), Vector3(0.035, 0.04, 2.75), Color("52686a"))
			seam.rotation.x = side * deg_to_rad(29)
	var gable_verts := PackedVector3Array([Vector3(-2.86, 3, -2.1), Vector3(-2.86, 4.2, 0), Vector3(-2.86, 3, 2.1), Vector3(2.86, 3, -2.1), Vector3(2.86, 3, 2.1), Vector3(2.86, 4.2, 0)])
	Geo.triangle_surface(cabin, "Gables", gable_verts, PackedColorArray([Color("6c7c70"), Color("6c7c70"), Color("6c7c70"), Color("6c7c70"), Color("6c7c70"), Color("6c7c70")]))
	Geo.box(cabin, "Chimney", Vector3(1.6, 4, -0.6), Vector3(0.55, 2.2, 0.6), Color("7a7061"))
	Geo.box(cabin, "ChimneyCap", Vector3(1.6, 5.12, -0.6), Vector3(0.72, 0.18, 0.75), Color("465658"))
	var smoke := CPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.position = Vector3(1.6, 5.3, -0.6)
	smoke.amount = 12
	smoke.lifetime = 4.0
	smoke.preprocess = 4.0
	smoke.direction = Vector3(-0.4, 1, 0)
	smoke.spread = 15
	smoke.gravity = Vector3(-0.05, 0.02, 0)
	smoke.initial_velocity_min = 0.3
	smoke.initial_velocity_max = 0.6
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.4
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.17
	smoke_mesh.height = 0.34
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 3
	smoke.mesh = smoke_mesh
	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.material_override = smoke_material
	var smoke_gradient := Gradient.new()
	smoke_gradient.colors = PackedColorArray([Color(0.65, 0.7, 0.67, 0.18), Color(0.65, 0.7, 0.67, 0)])
	smoke.color_ramp = smoke_gradient
	cabin.add_child(smoke)
	Geo.box(cabin, "Porch", Vector3(0, 0.2, 2.8), Vector3(3.8, 0.4, 1.1), Color("857456"), true)
	Geo.box(cabin, "Step", Vector3(0, 0.1, 3.5), Vector3(2.4, 0.2, 0.4), Color("99866b"), true)
	for x in [-1.65, 1.65]:
		Geo.cylinder(cabin, "PorchPost", Vector3(x, 1.45, 3.1), 0.06, 2.6, Color("aa9472"))
	Geo.box(cabin, "PorchAwning", Vector3(0, 2.8, 2.8), Vector3(4.1, 0.15, 1.8), Color("455c60"))
	add_lamp(at + Vector3(3.8, 0, 2.4))
	var window_light := OmniLight3D.new()
	window_light.name = "CabinWindowGlow"
	window_light.position = at + Vector3(0, 2, 3.0)
	window_light.light_color = Color("ffcb85")
	window_light.light_energy = 1.8
	window_light.omni_range = 9
	world.add_child(window_light)
	station("shelter", "Хижина смотрителя", at + Vector3(0, 0, 3.7))
	var bench_at := at + Vector3(-3.8, 0, 3.5)
	Geo.box(land, "WorkbenchTop", bench_at + Vector3(0, 0.9, 0), Vector3(1.9, 0.18, 0.85), Color("a38b62"), true)
	for x in [-0.7, 0.7]:
		Geo.box(land, "WorkbenchLeg", bench_at + Vector3(x, 0.45, 0), Vector3(0.14, 0.9, 0.65), Color("6e5b43"))
	station("workbench", "Верстак · укрепление", bench_at + Vector3(0, 0, 1.1))
	var stove := at + Vector3(4.7, 0, 0.8)
	Geo.cylinder(land, "IronStove", stove + Vector3(0, 0.5, 0), 0.5, 1.0, Color("3b4a4c"), -1, true)
	Geo.cylinder(land, "StovePipe", stove + Vector3(0.3, 1.25, 0), 0.1, 1.1, Color("3b4a4c"))
	Geo.cylinder(land, "CookingPot", stove + Vector3(0, 1.1, 0), 0.32, 0.3, Color("6b7775"))
	station("cook", "Печь · приготовить рыбу", stove + Vector3(0, 0, 1.0))

func make_dock() -> void:
	var dock := Node3D.new()
	dock.name = "FishingDock"
	dock.position = Vector3(18.0, 0.8, 5)
	land.add_child(dock)
	for index in 17:
		Geo.box(dock, "DeckPlank", Vector3(index * 0.42, 0, 0), Vector3(0.39, 0.18, 2.2), Color("857d65").lightened(rng.randf_range(-0.05, 0.04)), true)
	for index in 4:
		for z in [-0.9, 0.9]:
			Geo.cylinder(dock, "TimberPile", Vector3(index * 2.0, -0.2, z), 0.13, 2.2, Color("5d675c"))
	for z in [-0.9, 0.9]:
		Geo.line(dock, "Rope", Vector3(0, 0.6, z), Vector3(6, 0.6, z), 0.025, Color("b2a381"))
	Geo.crate(dock, Vector3(5, 0.1, -0.4), 0.65)
	station("fish", "Причал · ловить рыбу", Vector3(23.3, 0.9, 5))
	Geo.line(land, "FishingRod", Vector3(23.8, 1.1, 4.7), Vector3(26.4, 2.4, 5.1), 0.035, Color("7a684b"))
	Geo.line(land, "FishingLine", Vector3(26.4, 2.4, 5.1), Vector3(26.7, 0.15, 5.1), 0.008, Color("c4cec0"))
	# Небольшая рыбацкая лодка рядом с причалом.
	var boat_at := Vector3(23.5, 0.15, 8)
	Geo.sphere(land, "BoatHull", boat_at, Vector3(3.7, 0.7, 1.5), Color("5e756e"))
	Geo.box(land, "BoatInside", boat_at + Vector3(0, 0.3, 0), Vector3(2.6, 0.13, 0.85), Color("354f52"))
	for x in [-0.7, 0.7]:
		Geo.box(land, "BoatSeat", boat_at + Vector3(x, 0.4, 0), Vector3(0.35, 0.1, 1.1), Color("ac9672"))

func make_forest() -> void:
	var positions := [
		Vector3(-12, 1, 7), Vector3(-9, 1, 9), Vector3(-6, 1, 11), Vector3(-3, 1, 12),
		Vector3(0, 1, 12), Vector3(-14, 1, 3), Vector3(-15, 1, -1), Vector3(-12, 1, 11),
		Vector3(7, 1, -10), Vector3(11, 1, -11), Vector3(14, 1, -8), Vector3(4, 1, -12),
		Vector3(1, 1, -11), Vector3(-4, 1, -12), Vector3(13, 1, 10), Vector3(9, 1, 11)
	]
	for at in positions:
		Geo.tree(land, at, rng.randf_range(1.5, 2.2), rng.randf_range(-0.015, 0.06))
	var log_at := Vector3(-5.5, 1.25, 7.2)
	for index in 3:
		var log_node := Geo.cylinder(land, "FallenLog", log_at + Vector3(index * 0.45, 0.05, 0), 0.22, 2.7, Color("7b674d"), -1, false)
		log_node.rotation_degrees.x = 90
		Geo.cylinder(land, "LogEnd", log_at + Vector3(index * 0.45, 0.05, 1.36), 0.19, 0.025, Color("b39d71")).rotation_degrees.x = 90
	station("wood", "Валежник · собрать древесину", Vector3(-4.5, 1, 6.8), 9)
	for index in 150:
		var at := Vector3(rng.randf_range(-17, 17), 1.04, rng.randf_range(-13, 13))
		if Vector2(at.x / 18.0, at.z / 14.0).length() > 0.95:
			continue
		if (absf(at.x - 5) < 4 and absf(at.z) < 5) or at.distance_to(Vector3(-9, 1, -7)) < 3:
			continue
		var height := rng.randf_range(0.18, 0.5)
		var green := Color("7b8c65").lightened(rng.randf_range(-0.1, 0.08))
		var vertices := PackedVector3Array([at + Vector3(-0.18, 0, 0), at + Vector3(0.06, height, 0), at + Vector3(0.18, 0, 0), at + Vector3(0, 0, -0.14), at + Vector3(0, height * 0.8, 0.05), at + Vector3(0, 0, 0.16)])
		Geo.triangle_surface(land, "CoastalGrass", vertices, PackedColorArray([green, green, green, green, green, green]))

func make_paths() -> void:
	path([Vector3(-7, 1.08, -4), Vector3(-4, 1.08, -2), Vector3(-1, 1.08, 0), Vector3(1, 1.08, 3), Vector3(5, 1.08, 4)])
	path([Vector3(5, 1.07, 4), Vector3(11, 1.07, 5), Vector3(18, 1.07, 5)])
	path([Vector3(-1, 1.07, 0), Vector3(-3, 1.07, 4), Vector3(-4, 1.07, 6)])
	path([Vector3(0, 1.07, 0), Vector3(4, 1.07, -4), Vector3(10, 1.07, -6)])

func path(points: Array) -> void:
	for index in points.size() - 1:
		var start: Vector3 = points[index]
		var end: Vector3 = points[index + 1]
		var segment := Geo.box(land, "Footpath", (start + end) * 0.5, Vector3(1.15, 0.018, start.distance_to(end)), Color("96957b"))
		segment.rotation.y = atan2(end.x - start.x, end.z - start.z)
		for pebble_index in 6:
			var at := start.lerp(end, rng.randf()) + Vector3(rng.randf_range(-0.6, 0.6), 0.02, rng.randf_range(-0.4, 0.4))
			Geo.sphere(land, "PathPebble", at, Vector3(0.15, 0.05, 0.1), Color("b1ac8d"))

func make_props() -> void:
	Geo.crate(land, Vector3(10, 1, -6))
	Geo.crate(land, Vector3(11.1, 1, -6.5), 0.75)
	Geo.box(land, "FuelCan", Vector3(10.3, 1.3, -4.9), Vector3(0.42, 0.6, 0.25), Color("ba7649"), true)
	Geo.box(land, "FuelHandle", Vector3(10.3, 1.65, -4.9), Vector3(0.24, 0.1, 0.08), Color("4f5b50"))
	station("fuel", "Припасы · канистра топлива", Vector3(10, 1, -4.4), 1)
	add_lamp(Vector3(11.7, 1, -5.0))
	for index in 8:
		Geo.rock(land, Vector3(rng.randf_range(-15, 14), 1.02, rng.randf_range(-11, 11)), Vector3(rng.randf_range(0.4, 1.3), rng.randf_range(0.3, 0.7), 0.9), Color("82908a"), rng.randf() * TAU)
	Geo.box(land, "SignPost", Vector3(-1, 1.7, -4), Vector3(0.12, 1.4, 0.12), Color("786a4e"))
	Geo.box(land, "WarningSign", Vector3(-1, 2.25, -4), Vector3(1.1, 0.6, 0.12), Color("c4b386"))
	station("note", "Табличка на тропе", Vector3(-1, 1, -3.5))
	Geo.box(land, "BarricadeBlueprint", Vector3(4.6, 1.07, 5.2), Vector3(3.8, 0.025, 0.25), Color("d9b970"))

func add_lamp(at: Vector3) -> void:
	Geo.cylinder(land, "LampPost", at + Vector3(0, 1.3, 0), 0.055, 2.6, Color("384e4c"))
	Geo.box(land, "LampHousing", at + Vector3(0, 2.6, 0), Vector3(0.32, 0.45, 0.32), Color("f2c983"), false, 1.3)
	Geo.cylinder(land, "LampCap", at + Vector3(0, 2.9, 0), 0.25, 0.18, Color("384e4c"), 0)
	var light := OmniLight3D.new()
	light.name = "PathLantern"
	light.position = at + Vector3(0, 2.5, 0)
	light.light_color = Color("ffcd89")
	light.light_energy = 2.0
	light.omni_range = 6.5
	world.add_child(light)

func station(id: String, title: String, at: Vector3, remaining: int = -1) -> void:
	var area := Area3D.new()
	area.name = "Station_" + id
	area.set_script(STATION)
	area.set("station_id", id)
	area.set("display_name", title)
	area.set("remaining", remaining)
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 2.4
	shape.shape = sphere_shape
	shape.position.y = 0.8
	area.add_child(shape)
	var marker := Label3D.new()
	marker.name = "InteractionMarker"
	marker.text = "◆"
	marker.font_size = 38
	marker.pixel_size = 0.014
	marker.position.y = 2.3
	marker.modulate = Color("e3bb76")
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(marker)
	world.add_child(area)

func make_lighting() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "CoastalAtmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2c4d5c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8bab9")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("708e92")
	env.fog_density = 0.003
	env.fog_sky_affect = 0
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -42, 0)
	sun.light_color = Color("ffe0ac")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	world.add_child(sun)
