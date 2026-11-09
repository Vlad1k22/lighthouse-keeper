extends SceneTree
## From the menu button through the day-one interactions to the radio ending.
var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: "+label)

func tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func place(at: Vector3) -> void:
	game.player.position = at
	game.player.reset_motion()
	game.interaction_cooldown = 0
	for i in 10:
		await physics_frame
	game.update_nearest()

func use_station(id: String, offset := Vector3.ZERO) -> void:
	var points: Dictionary = game.building_interiors.actions
	var item: Area3D
	for station in game.stations:
		if station.station_id == id:
			item = station
			break
	await place(points.get(id, item.position) + offset)
	await tap(KEY_E)

func write_text(path: String, body: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(body)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://automated_first_shift_demo.json"
	game.checkpoint_path = "user://automated_first_shift_demo_checkpoint.json"
	game.checkpoints_enabled = true
	write_text(game.save_path, "campaign manual fixture")
	write_text(game.checkpoint_path, "campaign checkpoint fixture")
	game.hud.first_shift_button.pressed.emit()
	game.hours_per_second = 0
	var demo = game.first_shift_demo
	check(demo.active() and demo.is_open() and game.paused and not game.player.enabled, "Menu opens the separate introduction and pauses movement")
	check(FileAccess.get_file_as_string(game.checkpoint_path)=="campaign checkpoint fixture", "Starting the episode preserves the campaign checkpoint")
	await tap(KEY_E)
	check(not demo.is_open() and game.player.enabled and game.campaign.target_id()=="fuel", "E closes the intro and reveals the fuel objective")
	check(not game.player.lantern_on and demo.hint().contains("WASD"), "The episode introduces movement before the lamp")
	await tap(KEY_F9)
	check(FileAccess.get_file_as_string(game.save_path)=="campaign manual fixture", "F9 cannot overwrite the campaign from the episode")
	await tap(KEY_F10)
	check(demo.active() and game.player.enabled, "F10 leaves the active episode in place")
	await use_station("fuel", Vector3(0,.11,.8))
	await use_station("beacon", Vector3(0,.11,.85))
	check(game.lighthouse_on and game.campaign.target_id()=="lighthouse_lens", "The real canister and generator lead to the tower objective")
	await place(game.LIGHTHOUSE_INTERIOR.OUTSIDE_DOOR)
	await tap(KEY_E)
	check(game.lighthouse_interior.active, "E at the tower door uses the existing interior")
	await place(game.LIGHTHOUSE_INTERIOR.ORIGIN+Vector3(1.25,game.LIGHTHOUSE_INTERIOR.TOP+.04,.9))
	await tap(KEY_E)
	check("c:1:2" in game.journal_entries, "Inspecting the lens records its warning")
	await place(game.LIGHTHOUSE_INTERIOR.ORIGIN+game.LIGHTHOUSE_INTERIOR.INSIDE_DOOR+Vector3.UP*.05)
	await tap(KEY_E)
	for i in 3:
		await use_station("wood", Vector3(0,.11,.85))
	await use_station("workbench", Vector3(0,.11,1))
	check(game.barricade_built and game.campaign.day_complete(), "Collecting wood and reinforcing the cabin completes the day")
	await place(game.building_interiors.exit_at("cabin"))
	await tap(KEY_E)
	check(game.building_interiors.active=="cabin", "The player enters the cabin through its porch door")
	await tap(KEY_F)
	await use_station("shelter")
	check(game.player.lantern_on and game.campaign.state.night, "F lights the lamp and E at the bunk starts the night")
	game.campaign.advance(6.2)
	check(game.campaign.first_window_strength()>.5, "The real first-night silhouette appears in the demo")
	game.campaign.advance(9)
	await use_station("shelter")
	check(demo.awaiting_contact() and game.day==1 and not game.campaign.state.night and game.campaign.target_id()=="radio", "Dawn remains in the episode and marks the home radio")
	var dawn: float = game.hour
	game.hours_per_second = .055
	await process_frame
	await process_frame
	check(is_equal_approx(game.hour,dawn), "Dawn waits for the radio call")
	await use_station("radio")
	check(demo.is_open() and game.paused and not game.player.enabled, "E at the receiver opens the subtitle and choices")
	check(demo.voice.playing and demo.voice.stream==demo.RADIO_CALL and demo.RADIO_CALL.get_length()>0, "The incoming voice plays with its subtitle")
	await tap(KEY_2)
	check(demo.response.text.contains("позывной маяка") and not game.finished, "A wrong reply gives feedback without ending the episode")
	await tap(KEY_J)
	check(game.journal_open and game.hud.reader_text.text.contains("Берег-четыре") and not demo.is_open(), "J opens the right journal entry from the dialogue")
	check(not demo.voice.playing, "Opening the journal stops the incoming voice")
	await tap(KEY_J)
	check(not game.journal_open and game.player.enabled, "Closing the journal returns control")
	await use_station("radio")
	check(demo.voice.playing and demo.voice.stream==demo.RADIO_CALL, "Reopening the receiver replays the incoming voice")
	await tap(KEY_1)
	check(demo.is_open() and demo.heading.text.contains("БЕРЕГ-ЧЕТЫРЕ") and not game.finished, "A correct answer reveals the dispatcher’s final reply")
	check(demo.voice.playing and demo.voice.stream==demo.RADIO_CONFIRM and demo.RADIO_CONFIRM.get_length()>0, "Confirmation switches to the matching recording on the same player")
	await tap(KEY_E)
	check(game.finished and game.last_run_won and game.hud.menu_title.text.contains("завершена"), "Acknowledging the radio reply opens the demo ending")
	check(not demo.voice.playing, "Finishing the demo stops the confirmation voice")
	check(FileAccess.get_file_as_string(game.save_path)=="campaign manual fixture" and FileAccess.get_file_as_string(game.checkpoint_path)=="campaign checkpoint fixture", "Finishing preserves both campaign saves")
	game.hud.start_button.pressed.emit()
	check(not demo.active() and not game.playing and game.hud.first_shift_button.visible and game.hud.demo_button.visible, "The ending returns to the title with both demonstrations")
	game.checkpoints_enabled = false
	game.hud.start_button.pressed.emit()
	check(game.playing and not demo.active() and game.campaign.calendar_days()==14 and not game.paused, "New campaign still starts directly on its 14-day calendar")
	for path in [game.save_path, game.checkpoint_path]:
		DirAccess.remove_absolute(path)
	print("FIRST SHIFT DEMO: %d/%d" % [checks-failures,checks])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
