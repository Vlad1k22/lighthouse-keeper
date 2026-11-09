extends SceneTree
## Native Godot captures at three heights. Does not alter the player's save.
const INTERIOR = preload("res://scripts/lighthouse_interior.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.player.position = INTERIOR.OUTSIDE_DOOR
	game.lighthouse_action()
	game.player.enabled = false
	game.message_time = 0
	var failed := false
	var views := [
		["interior-entry", INTERIOR.INSIDE_DOOR],
		["interior-stairs", INTERIOR.polar(1.62, TAU*1.64, INTERIOR.PITCH*1.64)],
		["interior-landing", INTERIOR.polar(1.52, .82, INTERIOR.TOP)],
	]
	for view in views:
		game.player.position = INTERIOR.ORIGIN + view[1] + Vector3.UP*.01
		game.player.reset_motion()
		game.camera_focus = game.player.position + Vector3.UP*.75
		game.lighthouse_on = view[0] == "interior-landing"
		game.beacon.set_powered(game.lighthouse_on)
		await create_timer(.45).timeout
		await RenderingServer.frame_post_draw
		var path := "res://docs/art/lighthouse/godot-%s.png" % view[0]
		failed = root.get_texture().get_image().save_png(path) != OK or failed
	game.queue_free()
	await process_frame
	quit(int(failed))
