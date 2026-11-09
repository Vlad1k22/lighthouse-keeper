extends SceneTree
const VISUAL = preload("res://scripts/lighthouse_visual.gd")

func _initialize() -> void:
	var scene: Node3D = load("res://scenes/world.tscn").instantiate()
	if not VISUAL.install(scene.get_node("IslandGeometry/Lighthouse")):
		push_error("Import the lighthouse GLB before installing its visual.")
		scene.free()
		quit(1)
		return
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:
		result = ResourceSaver.save(packed,"res://scenes/world.tscn")
	print("BLENDER_LIGHTHOUSE_INSTALLED ",result)
	scene.free()
	quit(result)
