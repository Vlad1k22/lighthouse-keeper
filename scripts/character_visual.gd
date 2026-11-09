extends RefCounted
## These paths are imported from Blender. Physics stays on the original CharacterBody3D.
const MODELS := {
	"keeper": "res://assets/models/characters/keeper_v01.glb",
	"shadow": "res://assets/models/characters/shadow_v01.glb",
	"drowned": "res://assets/models/characters/drowned_v01.glb",
}

static func install(container: Node3D, kind: String) -> Node3D:
	var existing := container.get_node_or_null("RiggedModel") as Node3D
	var path: String = MODELS.get(kind, MODELS.shadow)
	if existing != null and existing.scene_file_path == path:
		return existing
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	if existing != null:
		container.remove_child(existing)
		existing.free()
	for child in container.get_children():
		if child is Node3D:
			child.hide()
	var model := packed.instantiate() as Node3D
	model.name = "RiggedModel"
	container.add_child(model)
	if container.owner != null:
		model.owner = container.owner
	return model
