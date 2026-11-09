extends SceneTree
## Capture the actual gameplay cameras, with the regular UI and no save writes.
const BUILDINGS = preload("res://scripts/building_interiors.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.day = 5
	game.hour = 14
	game.player.enabled = false
	game.message_time = 0
	game.expedition.state.signal = true
	game.expedition.update_visuals()
	await process_frame
	game.message_time = 0
	var views := [
		["keeper-cabin", "cabin", Vector3(.12,0,-.32)],
		["radio-outpost", "radio", Vector3(.14,0,-.40)],
		["warehouse", "", Vector3(7.18,1,-30.84)],
		["vessel-deck", "", Vector3(-32.45,1,-20.38)],
		["vessel-cabin", "ship", Vector3(-.36,0,1.25)],
		["vessel-bridge", "ship", Vector3(.10,0,-.73)],
	]
	var failed := false
	for view in views:
		game.set_building_interior(view[1])
		game.player.position = view[2] + (Vector3.ZERO if view[1].is_empty() else BUILDINGS.ROOMS[view[1]].origin)
		game.player.reset_motion()
		await process_frame
		var inside: bool = not view[1].is_empty() or game.building_interiors.warehouse_open
		game.camera_focus = game.building_interiors.camera_focus(game.player.position) if inside else game.player.position+Vector3.UP
		game.target_zoom = 22
		game.camera_zoom = game.building_interiors.zoom() if inside else game.target_zoom
		game.update_camera(0)
		await create_timer(.34).timeout
		await RenderingServer.frame_post_draw
		var path := "res://docs/art/interiors/godot-%s.png" % view[0]
		failed = root.get_texture().get_image().save_png(path)!=OK or failed
	game.queue_free()
	await process_frame
	quit(int(failed))
