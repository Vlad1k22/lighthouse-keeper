extends SceneTree
const VISUAL = preload("res://scripts/ship_visual.gd")
func _initialize() -> void:
	var scene: Node3D = load("res://scenes/northern_coast.tscn").instantiate()
	if not VISUAL.install(scene.get_node("CoastalVessel")):
		push_error("Import the Blender GLB in Godot before installing it.")
		scene.free()
		quit(1)
		return
	VISUAL.sync(scene.get_node("CoastalVessel"),false,false,false)
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed,"res://scenes/northern_coast.tscn")
	print("BLENDER_SHIP_INSTALLED ",result)
	scene.free()
	quit(result)
