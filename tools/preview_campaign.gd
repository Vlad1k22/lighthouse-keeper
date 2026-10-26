extends SceneTree
## Native day/night/code UI showcase. Isolated fixture; never writes a player save/checkpoint.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled=false
	game.start_shift()
	game.hours_per_second=0
	game.day=14
	game.hour=17.2
	game.expedition.state.merge({"tools":true,"battery":true,"signal":true,"pump":true,"hull":true,"engine":true,"last_dawn":14,"scrap":5},true)
	game.barricade_built=true
	game.build_barricade()
	game.lighthouse_on=true
	game.beacon.set_powered(true)
	game.inventory.fuel=4
	game.inventory.wood=5
	game.campaign.ensure_day()
	game.campaign.state.beacon_charge=3
	game.campaign.state.completed_days=range(1,14)
	game.campaign.state.marks={"0":true,"1":true}
	game.expedition.update_visuals()
	game.player.position=Vector3(5.3,1.1,4.3)
	game.target_zoom=21
	game.camera_zoom=21
	game.camera_focus=game.player.position+Vector3(0,1,0)
	game.notify("День 14 · проверьте подготовку. Бирюзовая цель — следующий шаг. E у хижины приблизит ночь.",15)
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/campaign/day-preparation.png")
	game.expedition.open_board()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/campaign/map-and-plan.png")
	game.expedition.close_board()
	game.campaign.begin_night()
	game.hours_per_second=.055
	await create_timer(3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/campaign/night-event.png")
	game.hours_per_second=0
	game.clear_enemies()
	game.day=29
	game.hour=14
	game.campaign.ensure_day()
	game.expedition.state.last_dawn=29
	game.campaign.state.completed_days=range(1,29)
	game.campaign.state.beacon_charge=3
	game.lighthouse_on=true
	game.beacon.set_powered(true)
	for id in ["c:9:0","c:17:0","c:26:0","c:code"]:
		if id not in game.journal_entries:game.journal_entries.append(id)
	game.player.position=Vector3(-11.5,1.1,-35.35)
	game.target_zoom=24
	game.camera_zoom=24
	game.camera_focus=game.player.position+Vector3(0,1,0)
	await create_timer(1).timeout
	game.open_journal()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/campaign/journal-code.png")
	game.close_journal()
	var station: Area3D=game.world.get_node("NorthernCoast/Station_transmitter")
	game.attempt_interaction(station)
	game.campaign.code_input.text="314"
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/campaign/radio-code.png")
	print("CAMPAIGN_NATIVE_UI code_open=",game.campaign.code_open()," journal=",game.journal_entries.size())
	if "--stay" in OS.get_cmdline_user_args():return
	game.campaign.submit_code("314")
	game.queue_free()
	await create_timer(.3).timeout
	quit()
