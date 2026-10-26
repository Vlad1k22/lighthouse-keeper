extends RefCounted
## Installs a Blender-authored visual; gameplay collision bodies remain in Godot.
const MODEL := "res://assets/models/coastal_vessel/coastal_vessel_v01.glb"

static func install(vessel: Node3D) -> bool:
	if vessel.has_node("BlenderVisual"):
		return true
	if not ResourceLoader.exists(MODEL):
		return false
	var scene: PackedScene = load(MODEL)
	if scene == null:
		return false
	for child in vessel.find_children("*", "MeshInstance3D", true, false):
		child.hide()
	for child in vessel.find_children("*", "Label3D", true, false):
		child.hide()
	var visual := scene.instantiate()
	visual.name = "BlenderVisual"
	vessel.add_child(visual)
	if vessel.owner != null:
		visual.owner = vessel.owner
	return true

static func sync(vessel: Node3D, repaired: bool, engine: bool, sailing: bool) -> void:
	var visual := vessel.get_node_or_null("BlenderVisual")
	if visual == null:
		return
	for pair in [["SV_HullDamage",not repaired],["SV_HullPatch_Repaired",repaired],["SV_EngineReady",engine],["SV_Gangplank",not sailing]]:
		var node: Node3D = visual.find_child(pair[0], true, false)
		if node != null:
			node.visible = pair[1]
	# Legacy meshes still carry the tested StaticBody3D shapes.
	for name in ["HullPatch","HullDamage","EngineHatch"]:
		var node := vessel.find_child(name, true, false)
		if node != null:
			node.hide()
	var ramp := vessel.get_parent().get_node_or_null("ShipGangplank")
	if ramp != null:
		ramp.hide()
