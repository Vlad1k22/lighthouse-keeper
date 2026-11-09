extends SceneTree
## Native gameplay capture of the first apparition. Never writes player saves.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.fuel_found = true
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	game.barricade_built = true
	game.build_barricade()
	game.campaign.state.marks["2"] = true
	game.set_building_interior("cabin")
	game.player.enabled = false
	game.player.position = game.building_interiors.ROOMS.cabin.origin + Vector3(-.93,.015,-.48)
	game.camera_focus = game.building_interiors.camera_focus(game.player.position)
	game.camera_zoom = game.building_interiors.zoom()
	game.campaign.begin_night()
	game.campaign.advance(2.05)
	game.campaign.intercept("radio")
	game.campaign.advance(4.28)
	await create_timer(.45).timeout
	await RenderingServer.frame_post_draw
	var saved := root.get_texture().get_image().save_png("res://docs/campaign/first-watch-window.png")
	game.queue_free()
	await process_frame
	quit(0 if saved==OK else 1)
