extends SceneTree
const Overhaul = preload("res://scripts/visual_overhaul.gd")

func _initialize() -> void:
	call_deferred("run")

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner=scene
		own(child,scene)

func run() -> void:
	for path in ["res://scenes/world.tscn","res://scenes/keeper.tscn"]:
		var scene: Node3D = load(path).instantiate()
		root.add_child(scene)
		Overhaul.apply(scene)
		own(scene,scene)
		var packed := PackedScene.new()
		var result := packed.pack(scene)
		if result==OK:
			result=ResourceSaver.save(packed,path)
		print("Visual overhaul ",path," result=",result)
		scene.queue_free()
		if result!=OK:
			quit(1)
			return
	await process_frame
	quit()
