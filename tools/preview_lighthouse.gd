extends SceneTree
## Native captures of the playable island. Does not touch the player's save.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.set_process(false)
	var station: Area3D = game.world.get_node("Station_beacon")
	game.player.position = station.position + Vector3(.45,.15,1.0)
	game.player.velocity = Vector3.ZERO
	game.hud.game_ui.hide()
	game.hud.message_label.hide()
	var focus := Vector3(-8.2,6.6,-6.5)
	game.camera.position = focus + Vector3(21,19,32)
	game.camera.look_at(focus)
	game.camera.size = 17.2
	game.hour = 14.5
	game.update_atmosphere()
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var day_capture := root.get_texture().get_image().save_png("res://docs/art/lighthouse/godot-day.png")
	var fuel: Area3D = game.world.get_node("Station_fuel")
	var at_generator: Vector3 = game.player.position
	game.player.position = fuel.position
	game.attempt_interaction(fuel)
	game.player.position = at_generator
	var powered: bool = game.attempt_interaction(station)
	game.beacon.get_node("BeamPivot").rotation.y = -1.85
	game.hud.message_label.hide()
	game.hour = 21.7
	game.update_atmosphere()
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var night_capture := root.get_texture().get_image().save_png("res://docs/art/lighthouse/godot-night.png")
	print("LIGHTHOUSE_NATIVE_PREVIEW powered=",powered," capture=",day_capture,",",night_capture)
	if "--stay" in OS.get_cmdline_user_args():
		game.set_process(true)
		game.hud.game_ui.show()
		return
	game.queue_free()
	await process_frame
	quit(0 if powered and day_capture==OK and night_capture==OK else 1)
