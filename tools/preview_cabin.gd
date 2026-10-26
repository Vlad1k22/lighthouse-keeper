extends SceneTree
## Native Godot preview and repeatable local frame-time sample. Does not touch player saves.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.hour = 17.1
	game.player.position = Vector3(5.5,1.1,4.3)
	game.player.velocity = Vector3.ZERO
	game.target_zoom = 18
	game.camera_focus = game.player.position+Vector3(0,1,0)
	game.camera_zoom = 18
	game.notify("Хижина смотрителя · модель из Blender. Подъём на крыльцо без прыжка.",20)
	await create_timer(3).timeout
	var samples := PackedFloat32Array()
	var elapsed := 0.0
	while elapsed<4:
		await process_frame
		var delta: float = game.get_process_delta_time()
		elapsed += delta
		samples.append(delta)
	var sorted := samples.duplicate()
	sorted.sort()
	var report := {"viewport":"1280x800 (1440x900 canvas)","renderer":"Compatibility / OpenGL 3.3","device":RenderingServer.get_video_adapter_name(),"average_fps":samples.size()/elapsed,"frame_p95_ms":sorted[int(sorted.size()*.95)]*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"samples":samples.size(),"note":"One local sample at the cabin with the full game running; not a whole-game performance guarantee."}
	var file := FileAccess.open("res://docs/art/keeper_cabin/godot-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CABIN_PROFILE ",JSON.stringify(report))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/keeper_cabin/godot-in-game.png")
	game.hour = 21.5
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	game.night_spawned = true
	game.clear_enemies()
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/keeper_cabin/godot-night.png")
	if "--stay" in OS.get_cmdline_user_args():
		game.hour = 17.1
		return
	game.queue_free()
	await create_timer(.3).timeout
	quit()
