extends SceneTree
const VISUAL = preload("res://scripts/cabin_visual.gd")
func _initialize() -> void:
	var scene: Node3D = load("res://scenes/world.tscn").instantiate()
	var cabin: Node3D = scene.get_node("IslandGeometry/KeeperCabin")
	if not VISUAL.install(cabin):
		push_error("Import the Blender cabin GLB before installing it.")
		scene.free()
		quit(1)
		return
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:
		result = ResourceSaver.save(packed,"res://scenes/world.tscn")
	print("BLENDER_CABIN_INSTALLED ",result)
	scene.free()
	quit(result)
