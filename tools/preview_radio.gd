extends SceneTree
## Real Godot day-four fixture: repair the Blender transmitter without touching player saves.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.day = 4
	game.hour = 15.5
	game.expedition.state.merge({"tools":true,"battery":true,"scrap":4,"last_dawn":4},true)
	game.expedition.update_visuals()
	game.player.position = Vector3(-11.5,1.1,-35.35)
	game.player.velocity = Vector3.ZERO
	game.target_zoom = 24
	game.camera_focus = game.player.position+Vector3(0,1,0)
	game.camera_zoom = 24
	game.notify("Пост связи 04 · передатчику нужен ремонт. Инструменты, аккумулятор и детали подготовлены.",20)
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
	var report := {"viewport":"1280x800 (1440x900 canvas)","renderer":"Compatibility / OpenGL 3.3","device":RenderingServer.get_video_adapter_name(),"average_fps":samples.size()/elapsed,"frame_p95_ms":sorted[int(sorted.size()*.95)]*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"samples":samples.size(),"note":"Single local full-game sample at the radio station; other views/hardware may differ."}
	var file := FileAccess.open("res://docs/art/radio_station/godot-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("RADIO_PROFILE ",JSON.stringify(report))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/radio_station/godot-before-repair.png")
	if "--stay" in OS.get_cmdline_user_args():
		return
	var station: Area3D = game.world.get_node("NorthernCoast/Station_transmitter")
	var repaired: bool = game.attempt_interaction(station)
	print("RADIO_NATIVE_REPAIR ",repaired," signal=",game.expedition.state.signal," parts_left=",game.expedition.state.scrap)
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/radio_station/godot-in-game.png")
	game.hour = 21.5
	game.night_spawned = true
	game.clear_enemies()
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/radio_station/godot-night.png")
	game.queue_free()
	await create_timer(.3).timeout
	quit(0 if repaired else 1)
