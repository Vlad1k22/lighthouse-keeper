extends RefCounted
## Blender exterior replacement. The existing simple Godot collision stays authoritative.
const MODEL := "res://assets/models/keeper_cabin/keeper_cabin_v01.glb"

static func install(cabin: Node3D) -> bool:
	if cabin.has_node("BlenderVisual"):
		return true
	if not ResourceLoader.exists(MODEL):
		return false
	var packed: PackedScene = load(MODEL)
	if packed == null:
		return false
	for child in cabin.find_children("*", "MeshInstance3D", true, false):
		child.hide()
	var visual: Node3D = packed.instantiate()
	visual.name = "BlenderVisual"
	cabin.add_child(visual)
	if cabin.owner != null:
		visual.owner = cabin.owner
	# Light, smoke, physics and interactions are authored in Godot, not exported from Blender.
	var lamp := OmniLight3D.new()
	lamp.name = "EntryLanternLight"
	lamp.position = Vector3(.94,1.95,2.65)
	lamp.light_color = Color("ffbd75")
	lamp.light_energy = .55
	lamp.omni_range = 3.2
	lamp.shadow_enabled = false
	cabin.add_child(lamp)
	if cabin.owner != null:
		lamp.owner = cabin.owner
	# A convex ramp matches the Blender boarding ramp, bridging both original step faces.
	var body := StaticBody3D.new()
	body.name = "PorchAccessRamp"
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for x in [-.64,.64]:
		for yz in [Vector2(-.05,4.1),Vector2(-.05,3.2),Vector2(.4,3.2),Vector2(.4,3.4),Vector2(0,4.1)]:
			points.append(Vector3(x,yz.x,yz.y))
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.name = "RampCollision"
	collision.shape = shape
	body.add_child(collision)
	cabin.add_child(body)
	if cabin.owner != null:
		body.owner = cabin.owner
		collision.owner = cabin.owner
	return true
