extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ISLAND_SIZE := 36.0

var player: CharacterBody3D
var hud_label: Label
var has_fuel := false
var lighthouse_on := false
var fuel_position := Vector3(-3.0, 0.0, 4.0)
var lighthouse_position := Vector3(-8.0, 0.0, -7.0)

func _ready() -> void:
	build_world()
	build_player()
	build_hud()
	update_hud()

func build_world() -> void:
	var water_material := make_material(Color("315e69"))
	var water := MeshInstance3D.new()
	water.name = "Water"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(100, 100)
	water.mesh = water_mesh
	water.position.y = -0.48
	water.material_override = water_material
	add_child(water)

	# Песчаный край и травяная площадка в центре острова.
	add_box("Beach", Vector3(36, 0.5, 36), Vector3(0, -0.24, 0), Color("b69b68"))
	add_box("Island grass", Vector3(30, 0.5, 30), Vector3(0, -0.04, 0), Color("667b50"))

	# Маяк: башня, площадка и светлая верхняя часть.
	add_cylinder("Lighthouse tower", 1.0, 8.0, lighthouse_position + Vector3(0, 4, 0), Color("d5c9a6"))
	add_cylinder("Lighthouse balcony", 1.35, 0.35, lighthouse_position + Vector3(0, 8.05, 0), Color("49494a"))
	add_cylinder("Lantern room", 1.05, 1.2, lighthouse_position + Vector3(0, 8.8, 0), Color("d58a48"))
	add_cylinder("Lighthouse roof", 1.2, 0.4, lighthouse_position + Vector3(0, 9.6, 0), Color("4d4640"))
	add_box("Lighthouse door", Vector3(0.7, 1.3, 0.12), lighthouse_position + Vector3(0, 0.65, 1.02), Color("43372c"), false)

	# Хижина.
	add_box("Cabin", Vector3(5, 3, 4), Vector3(7, 1.5, -6), Color("806244"))
	add_box("Cabin roof", Vector3(5.6, 0.45, 4.6), Vector3(7, 3.25, -6), Color("453b35"), false)
	add_box("Cabin door", Vector3(0.9, 1.8, 0.15), Vector3(7, 0.9, -3.92), Color("362c25"), false)

	# Пятна леса, чтобы на острове было куда сходить за ресурсами.
	for tree_data in [
		[Vector3(8, 0, 5), 1.0], [Vector3(11, 0, 7), 0.85], [Vector3(6, 0, 10), 0.9],
		[Vector3(12, 0, 11), 1.1], [Vector3(3, 0, 12), 0.8], [Vector3(-2, 0, 10), 0.9]
	]:
		add_tree(tree_data[0], tree_data[1])

	# Несколько камней и ящик рядом с топливной канистрой.
	add_box("Supply crate", Vector3(1.1, 0.8, 1.0), fuel_position + Vector3(1.2, 0.4, 0), Color("76583a"))
	add_cylinder("Fuel can", 0.38, 0.8, fuel_position + Vector3(0, 0.4, 0), Color("b44b37"), false)
	add_cylinder("Rock 1", 0.8, 0.65, Vector3(-12, 0.32, 8), Color("777873"), false)
	add_cylinder("Rock 2", 0.55, 0.5, Vector3(13, 0.25, -1), Color("85847c"), false)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("78939a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c6d1c7")
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.2
	add_child(sun)

func build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 0.9, 3)
	add_child(player)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	player.add_child(collision)

	var character_mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.42
	capsule_mesh.height = 1.8
	character_mesh.mesh = capsule_mesh
	character_mesh.material_override = make_material(Color("d1b37c"))
	player.add_child(character_mesh)

	var camera := Camera3D.new()
	camera.name = "IsometricCamera"
	camera.position = Vector3(0, 13, 13)
	camera.rotation_degrees = Vector3(-45, 0, 0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32.0
	camera.current = true
	player.add_child(camera)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_label = Label.new()
	hud_label.position = Vector2(22, 18)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color("fff4d6"))
	hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	hud_label.add_theme_constant_override("shadow_offset_x", 2)
	hud_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_E:
		return
	if not has_fuel and player.global_position.distance_to(fuel_position) < 2.2:
		has_fuel = true
		update_hud()
	elif has_fuel and not lighthouse_on and player.global_position.distance_to(lighthouse_position) < 2.6:
		lighthouse_on = true
		var lamp := OmniLight3D.new()
		lamp.position = lighthouse_position + Vector3(0, 9.0, 0)
		lamp.light_color = Color("ffd783")
		lamp.omni_range = 16.0
		lamp.light_energy = 2.0
		add_child(lamp)
		update_hud()

func update_hud() -> void:
	if lighthouse_on:
		hud_label.text = "День 1  •  Маяк снова горит!\nWASD — ходить   E — действие"
	elif has_fuel:
		hud_label.text = "День 1  •  Отнесите топливо к маяку\nWASD — ходить   E — действие"
	else:
		hud_label.text = "День 1  •  Найдите красную канистру у ящика\nWASD — ходить   E — действие"

func add_tree(at: Vector3, scale_factor: float) -> void:
	add_cylinder("Tree trunk", 0.32 * scale_factor, 2.2 * scale_factor, at + Vector3(0, 1.1 * scale_factor, 0), Color("584634"))
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.45 * scale_factor
	crown_mesh.height = 2.7 * scale_factor
	crown.mesh = crown_mesh
	crown.position = at + Vector3(0, 2.75 * scale_factor, 0)
	crown.material_override = make_material(Color("435a40"))
	add_child(crown)

func add_box(node_name: String, dimensions: Vector3, at: Vector3, color: Color, solid := true) -> void:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.name = node_name
		var shape := BoxShape3D.new()
		shape.size = dimensions
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		root = body
	else:
		root = Node3D.new()
		root.name = node_name
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.material_override = make_material(color)
	root.add_child(mesh_instance)
	root.position = at
	add_child(root)

func add_cylinder(node_name: String, radius: float, height: float, at: Vector3, color: Color, solid := true) -> void:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.name = node_name
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		root = body
	else:
		root = Node3D.new()
		root.name = node_name
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = make_material(color)
	root.add_child(mesh_instance)
	root.position = at
	add_child(root)

func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
