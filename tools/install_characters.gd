extends SceneTree
const VISUAL = preload("res://scripts/character_visual.gd")

func _initialize() -> void:
	for kind in ["keeper", "shadow"]:
		var path: String = "res://scenes/" + kind + ".tscn"
		var source := load(path) as PackedScene
		var character := source.instantiate() as Node3D
		var model := VISUAL.install(character.get_node("Visual"), kind)
		if model == null or model.find_children("*", "Skeleton3D", true, false).is_empty():
			push_error("The Blender model or its armature is missing: " + kind)
			character.free()
			quit(1)
			return
		var packed := PackedScene.new()
		var result := packed.pack(character)
		if result == OK:
			result = ResourceSaver.save(packed, path)
		character.free()
		if result != OK:
			quit(result)
			return
		print("CHARACTER_INSTALLED ",kind)
	quit()
