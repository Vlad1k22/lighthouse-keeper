extends RefCounted
## Keep the original beacon, collision bodies and generator. Replace only the tower's visible meshes.
const MODEL := "res://assets/models/lighthouse/lighthouse_v01.glb"

static func install(beacon: Node3D) -> bool:
	if beacon.has_node("BlenderVisual"):
		return true
	if not ResourceLoader.exists(MODEL):
		return false
	var packed := load(MODEL) as PackedScene
	if packed == null:
		return false
	var visual := packed.instantiate() as Node3D
	if not visual.has_node("LH_Lens") or not visual.has_node("LH_Glass"):
		visual.free()
		return false
	for child in beacon.get_children():
		if child is MeshInstance3D:
			child.hide()
	visual.name = "BlenderVisual"
	beacon.add_child(visual)
	if beacon.owner != null:
		visual.owner = beacon.owner
	return true
