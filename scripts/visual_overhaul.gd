extends RefCounted
const Natural = preload("res://scripts/natural_geometry.gd")

static func apply(root: Node3D) -> void:
	if root.has_node("CoastalAtmosphere"):
		var environment: Environment = root.get_node("CoastalAtmosphere").environment
		environment.ambient_light_energy=0.48
		environment.fog_density=0.0045
		root.get_node("Sun").light_energy=0.90
	# Work on existing scene nodes: preserve all stations, scripts and collision bodies.
	for node in root.find_children("*", "Node3D", true, false):
		if not is_instance_valid(node):
			continue
		if node.has_node("Trunk") and node.has_node("WindNeedles"):
			var size: float = node.get_node("Trunk").mesh.height/1.7
			for child in node.get_children():
				node.remove_child(child)
				child.free()
			Natural.pine(node,size)
		elif node.has_node("Leaves"):
			var leaf_size: float = node.get_node("Leaves").scale.x/0.7
			for child in node.get_children():
				node.remove_child(child)
				child.free()
			var fronds := SurfaceTool.new()
			fronds.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 14:
				var angle := i*2.4
				Natural.frond(fronds,Vector3.ZERO,Vector3(cos(angle)*leaf_size*0.55,leaf_size*(0.35+sin(i)*0.1),sin(angle)*leaf_size*0.55),leaf_size*0.17,0.6)
			var mat := ShaderMaterial.new()
			mat.shader=Natural.NEEDLES
			mat.set_shader_parameter("leaf_color",Color("45503a"))
			Natural.mesh_node(node,"CoastalFernFronds",fronds,mat)
	var rock_mesh := Natural.rock_mesh()
	var grass_mesh := Natural.grass_mesh()
	var material_cache := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if not node.material_override is StandardMaterial3D:
			continue
		var old: StandardMaterial3D = node.material_override
		if old.emission_enabled or old.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var kind := 0
		var color := old.albedo_color
		if old.vertex_color_use_as_albedo and node.mesh.get_surface_count()>0:
			var colors: PackedColorArray = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			if not colors.is_empty():
				color=colors[0]
		var path := str(root.get_path_to(node))
		var name := str(node.name)
		var is_rock := name.begins_with("CoastalRock")
		var is_grass := false
		var is_path := name.to_lower().contains("path")
		if node.mesh is ArrayMesh and old.vertex_color_use_as_albedo:
			var count: int = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
			var bounds: AABB = node.mesh.get_aabb()
			is_rock = is_rock or (count==18 and bounds.size.y>0.1)
			is_grass = count==6 and bounds.size.y>0.1 and bounds.size.y<0.6 and bounds.size.x<0.6
			is_path = is_path or (count==24 and bounds.size.y<0.01)
		if is_grass:
			var bounds: AABB = node.mesh.get_aabb()
			node.position+=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
			node.scale=Vector3(0.55,bounds.size.y*1.3,0.55)
			node.mesh=grass_mesh
			color=Color("68664a")
			kind=3
		elif is_rock:
			var bounds: AABB = node.mesh.get_aabb()
			node.mesh=rock_mesh
			node.scale=Vector3(bounds.size.x,bounds.size.y/0.68,bounds.size.z)
			color=Color("696b61")
		elif name=="Grassland":
			kind=4
		elif name=="SandShore" or is_path:
			kind=5
		elif name=="Cliffs":
			color=Color("62645e")
		elif path.contains("Lighthouse") and node.mesh is CylinderMesh and node.mesh.height>1.5 and node.mesh.bottom_radius>0.7:
			kind=2
			color=color.darkened(0.08)
		elif path.contains("KeeperCabin") or path.contains("FishingDock") or path.contains("TimberBarrel") or path.contains("SupplyCrate") or name.contains("Timber") or name.contains("Workbench"):
			kind=1
			if name.contains("Roof") or name.contains("Iron") or name.contains("Hinge") or name.contains("Chimney"):
				kind=6
		elif path.contains("Visual"):
			kind=3
		elif name.contains("Radio") or name.contains("Stove") or path.contains("Lighthouse") or name.contains("Generator"):
			kind=6
		if node.mesh is CylinderMesh:
			var mesh: CylinderMesh = node.mesh.duplicate()
			mesh.radial_segments=32
			node.mesh=mesh
		elif node.mesh is SphereMesh:
			var mesh: SphereMesh = node.mesh.duplicate()
			mesh.radial_segments=32
			mesh.rings=16
			node.mesh=mesh
		var key := str(kind)+color.to_html()
		if not material_cache.has(key):
			material_cache[key]=Natural.surface(color,kind)
		node.material_override=material_cache[key]
