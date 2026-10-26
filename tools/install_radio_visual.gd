extends SceneTree
const VISUAL = preload("res://scripts/radio_visual.gd")
func _initialize() -> void:
	var coast: Node3D = load("res://scenes/northern_coast.tscn").instantiate()
	if not VISUAL.install(coast):
		push_error("Import the radio GLB in Godot first.")
		coast.free()
		quit(1)
		return
	VISUAL.sync(coast,false)
	var packed := PackedScene.new()
	var result := packed.pack(coast)
	if result == OK:
		result = ResourceSaver.save(packed,"res://scenes/northern_coast.tscn")
	print("BLENDER_RADIO_INSTALLED ",result)
	coast.free()
	quit(result)
