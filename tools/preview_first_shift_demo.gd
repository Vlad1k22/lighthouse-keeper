extends SceneTree
## Native captures of the demo UI. Does not write player saves.
func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png("res://docs/campaign/demo-%s.png" % name)==OK

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_first_shift_demo()
	var intro := await capture("intro")
	game.first_shift_demo.begin_watch()
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	game.set_building_interior("cabin")
	game.player.position = game.building_interiors.actions["radio"]
	game.player.reset_motion()
	game.player.lantern_on = true
	game.place_camera_after_door(game.building_interiors.camera_focus(game.player.position),game.building_interiors.zoom())
	game.first_shift_demo.start_contact()
	game.message_time = 0
	game.first_shift_demo.open_radio()
	var radio := await capture("radio")
	game.first_shift_demo.choose(true)
	game.first_shift_demo.accept()
	var ending := await capture("ending")
	game.queue_free()
	await process_frame
	print("DEMO_NATIVE_CAPTURES intro=",intro," radio=",radio," ending=",ending)
	quit(0 if intro and radio and ending else 1)
