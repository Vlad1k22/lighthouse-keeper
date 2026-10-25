extends RefCounted
const SURFACE = preload("res://shaders/weathered_surface.gdshader")
const NEEDLES = preload("res://shaders/pine_needles.gdshader")

static func surface(color: Color, kind: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("surface_kind", kind)
	return mat

static func tube(tool: SurfaceTool, start: Vector3, end: Vector3, radius: float) -> void:
	var axis := (end-start).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.1:
		side = Vector3.RIGHT
	var up := axis.cross(side).normalized()
	for i in 7:
		var a := TAU*i/7.0
		var b := TAU*(i+1)/7.0
		var pa := (side*cos(a)+up*sin(a))*radius
		var pb := (side*cos(b)+up*sin(b))*radius
		for v in [start+pa,start+pb,end+pa*0.18,start+pb,end+pb*0.18,end+pa*0.18]:
			tool.add_vertex(v)

static func frond(tool: SurfaceTool, from: Vector3, to: Vector3, width: float, tilt: float) -> void:
	var axis := (to-from).normalized()
	var side := axis.cross(Vector3.UP).normalized().rotated(axis,tilt)*width
	var points := [from-side,from+side,to+side*0.35,to-side*0.35]
	var uv := [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)]
	for i in [0,1,2,0,2,3]:
		tool.set_uv(uv[i])
		tool.add_vertex(points[i])

static func mesh_node(parent: Node3D, name: String, tool: SurfaceTool, mat: Material) -> MeshInstance3D:
	tool.set_smooth_group(0)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = tool.commit()
	node.material_override = mat
	parent.add_child(node)
	return node

static func pine(root: Node3D, size: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(root.position.x*1349+root.position.z*2767))+42
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := size*3.0
	tube(wood,Vector3.ZERO,Vector3(size*0.10,height,0),size*0.075)
	for level in 9:
		var y := size*(0.7+level*0.24)
		for branch in 5:
			var angle := branch*TAU/5.0+level*1.7+rng.randf_range(-0.2,0.2)
			var length := size*(0.95-level*0.085)*rng.randf_range(0.8,1.2)
			var start := Vector3(0,y,0)
			var end := Vector3(cos(angle)*length,y+rng.randf_range(-0.2,0.25)*size,sin(angle)*length)
			tube(wood,start,end,size*0.018)
			for spray in 7:
				var t := 0.24+spray*0.1
				var center := start.lerp(end,t)
				for side in [-1.0,1.0]:
					var direction := Vector3(cos(angle+side*0.65),0.15,sin(angle+side*0.65))
					var tip := center+direction*size*(0.30-level*0.015)*rng.randf_range(0.8,1.15)
					frond(leaves,center,tip,size*0.115,side*0.5)
					frond(leaves,center,tip,size*0.105,side*1.9)
	mesh_node(root,"WeatheredBranches",wood,surface(Color("514637"),1))
	var mat := ShaderMaterial.new()
	mat.shader = NEEDLES
	mat.set_shader_parameter("leaf_color",Color("344633").lightened(rng.randf_range(-0.025,0.025)))
	mesh_node(root,"PineNeedleSprays",leaves,mat)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CylinderShape3D.new()
	capsule.radius=size*0.085
	capsule.height=size*1.7
	collision.shape=capsule
	collision.position.y=size*0.85
	body.add_child(collision)
	root.add_child(body)

static func rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments=20
	sphere.rings=12
	sphere.radius=0.5
	sphere.height=1.0
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var v := vertices[i]
		var distortion := 1.0+sin(v.x*17+v.z*8)*0.10+cos(v.z*19-v.y*14)*0.08
		vertices[i]=Vector3(v.x*distortion,(v.y+0.5)*distortion*0.68,v.z*distortion)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func grass_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 11:
		var angle := i*2.4
		var width := Vector3(cos(angle),0,sin(angle))*0.045
		var base := Vector3(sin(i*3.1),0,cos(i*2.7))*0.25
		var bend := Vector3(cos(angle),0,sin(angle))*0.25
		var middle := base+Vector3.UP*0.45+bend*0.35
		var top := base+Vector3.UP*(0.65+0.30*sin(i*1.5))+bend
		for v in [base-width,base+width,middle-width*0.6,base+width,middle+width*0.6,middle-width*0.6,middle-width*0.6,middle+width*0.6,top]:
			tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()
