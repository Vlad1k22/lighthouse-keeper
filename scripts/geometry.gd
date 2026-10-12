@static_unload
extends RefCounted
## Небольшие собственные low-poly модели. Используется при сборке редактируемой сцены.

static var materials: Dictionary = {}

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := color.to_html() + str(glow)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	materials[key] = mat
	return mat

static func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: Color, solid: bool = false, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color, glow)
	node.position = at
	parent.add_child(node)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		collider(node, shape)
	return node

static func cylinder(parent: Node3D, title: String, at: Vector3, radius: float, height: float, color: Color, top: float = -1.0, solid: bool = false, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = at
	node.material_override = material(color, glow)
	parent.add_child(node)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collider(node, shape)
	return node

static func collider(parent: Node3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

static func sphere(parent: Node3D, title: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 4
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	node.scale = size
	parent.add_child(node)
	return node

static func line(parent: Node3D, title: String, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var node := cylinder(parent, title, (start + end) * 0.5, radius, start.distance_to(end), color)
	var direction := (end - start).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP, direction)

static func triangle_surface(parent: Node3D, title: String, vertices: PackedVector3Array, colors: PackedColorArray) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for index in vertices.size():
		tool.set_color(colors[index])
		tool.add_vertex(vertices[index])
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = tool.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	parent.add_child(node)
	return node

static func rock(parent: Node3D, at: Vector3, size: Vector3, color: Color, angle: float = 0.0) -> void:
	var points := [
		Vector3(-0.5, 0.0, -0.35), Vector3(0.4, 0.02, -0.45),
		Vector3(0.55, 0.05, 0.3), Vector3(-0.35, 0.0, 0.5),
		Vector3(-0.15, 0.65, -0.12), Vector3(0.2, 0.52, 0.18)
	]
	var faces := [[0, 1, 4], [1, 2, 5], [1, 5, 4], [2, 3, 5], [3, 0, 4], [3, 4, 5]]
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for face_index in faces.size():
		for index in faces[face_index]:
			verts.append(points[index] * size)
			colors.append(color.lightened(float(face_index % 3) * 0.035))
	var node := triangle_surface(parent, "CoastalRock", verts, colors)
	node.position = at
	node.rotation.y = angle

static func tree(parent: Node3D, at: Vector3, size: float, variation: float) -> void:
	var root := Node3D.new()
	root.name = "Pine"
	root.position = at
	parent.add_child(root)
	root.rotation.y = fmod(absf(at.x * 3.1 + at.z * 1.9), TAU)
	cylinder(root, "Trunk", Vector3(0, size * 0.85, 0), size * 0.085, size * 1.7, Color("584a3c"), size * 0.045, true)
	for branch in 5:
		var angle := branch * 2.4
		line(root, "BareBranch", Vector3(0, size * 0.8, 0), Vector3(cos(angle) * size * 0.55, size, sin(angle) * size * 0.55), 0.035, Color("584a3c"))
	for level in 5:
		var width := size * (0.88 - level * 0.14)
		var color := Color("31564a").lightened(variation + level * 0.028)
		var offset := Vector3(sin(level * 2.5) * size * 0.09, size * (1.1 + level * 0.41), cos(level * 2.0) * size * 0.06)
		var needles := cylinder(root, "WindNeedles", offset, width, size * 1.05, color, 0)
		needles.mesh.radial_segments = 7
		needles.rotation.y = level * 0.6
		needles.rotation.z = sin(level * 1.7 + at.x) * 0.08
		needles.material_override = foliage_material(color, 0.045)
	for branch in 4:
		var angle := branch * 1.57 + 0.5
		var offset := Vector3(cos(angle) * size * 0.55, size * 1.2, sin(angle) * size * 0.55)
		var needles := cylinder(root, "OuterBough", offset, size * 0.43, size * 0.85, Color("31594b"), 0)
		needles.mesh.radial_segments = 6
		needles.rotation.z = cos(angle) * 0.25
		needles.material_override = foliage_material(Color("31594b").lightened(variation), 0.06)

static func foliage_material(color: Color, sway: float = 0.07) -> ShaderMaterial:
	var key := "foliage" + color.to_html() + str(sway)
	if materials.has(key):
		return materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/foliage.gdshader")
	mat.set_shader_parameter("leaf_color", color)
	mat.set_shader_parameter("sway", sway)
	materials[key] = mat
	return mat

static func shrub(parent: Node3D, at: Vector3, size: float, color: Color) -> void:
	var root := Node3D.new()
	root.name = "CoastalShrub"
	root.position = at
	parent.add_child(root)
	for index in 5:
		var angle := index * 2.4
		var leaves := sphere(root, "Leaves", Vector3(cos(angle) * size * 0.24, size * (0.3 + index * 0.04), sin(angle) * size * 0.24), Vector3(size * 0.7, size * 0.6, size * 0.65), color)
		leaves.material_override = foliage_material(color.lightened(index * 0.015))

static func barrel(parent: Node3D, at: Vector3, size: float = 1.0) -> void:
	var root := Node3D.new()
	root.name = "TimberBarrel"
	root.position = at
	root.scale = Vector3.ONE * size
	parent.add_child(root)
	cylinder(root, "Staves", Vector3(0, 0.5, 0), 0.37, 1.0, Color("8a7653"), 0.34, true)
	for y in [0.15, 0.8]:
		cylinder(root, "IronHoop", Vector3(0, y, 0), 0.38, 0.07, Color("415052"))
	for index in 10:
		var angle := index * TAU / 10
		line(root, "PlankSeam", Vector3(cos(angle) * 0.365, 0.03, sin(angle) * 0.365), Vector3(cos(angle) * 0.34, 0.97, sin(angle) * 0.34), 0.009, Color("594f3c"))
	cylinder(root, "Lid", Vector3(0, 1.01, 0), 0.33, 0.035, Color("a58d64"))

static func rope_coil(parent: Node3D, at: Vector3, radius: float = 0.35) -> void:
	var root := Node3D.new()
	root.name = "RopeCoil"
	root.position = at
	parent.add_child(root)
	for index in 3:
		var node := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius * (0.35 + index * 0.2)
		mesh.outer_radius = mesh.inner_radius + 0.045
		mesh.rings = 16
		mesh.ring_segments = 6
		node.mesh = mesh
		node.material_override = material(Color("b49e78"))
		node.position.y = index * 0.015
		root.add_child(node)

static func crate(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> void:
	var root := Node3D.new()
	root.name = "SupplyCrate"
	root.position = at
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	box(root, "Wood", Vector3(0, 0.42, 0), Vector3(0.9, 0.84, 0.8), Color("7c6347"), true)
	for x in [-0.4, 0.4]:
		box(root, "Brace", Vector3(x, 0.43, 0.42), Vector3(0.09, 0.85, 0.06), Color("af8e62"))
	for y in [0.1, 0.72]:
		box(root, "CrossBrace", Vector3(0, y, 0.44), Vector3(0.88, 0.09, 0.06), Color("af8e62"))
