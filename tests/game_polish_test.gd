extends SceneTree

var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: ",label)
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
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	var prefs = game.preferences
	prefs.path = "user://automated_lighthouse_settings.cfg"
	check(game.sound.music.playing and game.sound.music.bus=="Music","The title starts its own music on the Music channel")
	var save_probe := "user://automated_title_layout.json"
	if FileAccess.file_exists(save_probe):
		DirAccess.remove_absolute(save_probe)
	game.save_path = save_probe
	game.hud.show_menu("title")
	var hud: CanvasLayer = game.hud
	check(not hud.continue_button.visible and hud.first_shift_button.position.y>hud.start_button.position.y,"Title compacts the play buttons without a save")
	var fixture := FileAccess.open(save_probe,FileAccess.WRITE)
	fixture.store_string("{}")
	fixture.close()
	hud.show_menu("title")
	var play_buttons := [hud.start_button,hud.continue_button,hud.first_shift_button,hud.demo_button]
	var aligned: bool = hud.continue_button.visible
	for i in play_buttons.size()-1:
		var first: Button = play_buttons[i]
		var next: Button = play_buttons[i+1]
		aligned = aligned and first.position.x==next.position.x and first.size.x==next.size.x and first.get_rect().end.y<next.position.y
	check(aligned and hud.settings_button.position.y==hud.exit_button.position.y and hud.settings_button.position.y>hud.demo_button.get_rect().end.y,"Title keeps four aligned play buttons and one utility row with a save")
	DirAccess.remove_absolute(save_probe)
	hud.show_menu("title")
	var sign_labels := 0
	var captions_fit := true
	for child in game.world.get_node("NorthernCoast").get_children():
		if child is Label3D:
			sign_labels += 1
			var width := ThemeDB.fallback_font.get_string_size(child.text,HORIZONTAL_ALIGNMENT_LEFT,-1,child.font_size).x
			captions_fit = captions_fit and (width+2*child.outline_size)*child.pixel_size<=2.61
	check(sign_labels==10 and captions_fit,"All five roadside signs keep both lines inside the wooden board")
	game.hud.settings_button.pressed.emit()
	var settings = game.hud.settings_panel
	check(settings.visible,"The main menu opens its settings screen")
	settings.resolution.select(0)
	settings.quality.select(0)
	settings.fullscreen.button_pressed = true
	settings.sliders[0].value = .25
	settings.sliders[1].value = 0.0
	settings.sliders[2].value = .6
	settings.apply_settings()
	check(prefs.size_index==0 and prefs.fullscreen and root.msaa_3d==Viewport.MSAA_DISABLED and not game.world.get_node("Sun").shadow_enabled,"The economy preset and video choices are applied")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Dialogue")) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Environment")),linear_to_db(.25)),"Voice and environmental volumes use independent buses")
	prefs.size_index = 2
	prefs.fullscreen = false
	prefs.high_quality = true
	prefs.load_preferences()
	check(prefs.size_index==0 and prefs.fullscreen and not prefs.high_quality and is_equal_approx(prefs.volumes[2],.6),"Window, preset and volume choices survive reloading the settings file")
	await tap(KEY_ESCAPE)
	check(not settings.visible and not game.playing,"Esc returns from settings to the title")
	game.start_shift()
	await tap(KEY_ESCAPE)
	check(game.paused and game.hud.settings_button.visible,"The settings button is available while paused")
	await tap(KEY_ESCAPE)
	check(not game.paused and not game.sound.music.playing,"Starting play stops the title music")
	game.set_building_interior("cabin")
	game.player.position = game.building_interiors.ROOMS.cabin.origin+Vector3(-1.70,.05,1.51)
	game.player.reset_motion()
	check(game.extras.prompt().contains("граммофон"),"The prop offers its interaction from the cabin floor")
	await tap(KEY_E)
	check(game.extras.record_player.playing and game.extras.record_player.bus=="Music","E starts spatial music at the gramophone")
	game.set_building_interior("ship")
	check(not game.extras.record_player.playing,"Leaving the cabin stops the record")
	game.player.position = game.building_interiors.ROOMS.ship.origin+Vector3(.73,.05,1.93)
	game.player.reset_motion()
	game.interaction_cooldown = 0
	await tap(KEY_E)
	check(game.journal_open and game.hud.reader_title.text.contains("экипажа") and game.hud.reader_text.text.contains("ИУК2-53Б") and game.hud.reader_text.text.contains("Артамонов Артем"),"The hidden crew sheet opens the presentation names in the journal")
	await process_frame
	await process_frame
	var reader: RichTextLabel = hud.reader_text
	check(reader.clip_contents and reader.get_content_height()<=reader.size.y and reader.get_rect().end.y<hud.reader_count.position.y,"The full crew entry fits above the journal controls")
	hud.show_journal("Длинная запись",("Запись предыдущего смотрителя.\n").repeat(40),"НАХОДКИ")
	await process_frame
	await process_frame
	check(reader.get_v_scroll_bar().visible and reader.get_v_scroll_bar().max_value>reader.get_v_scroll_bar().page,"Overflow stays within a scrollable reading area")
	await tap(KEY_DOWN)
	check(reader.get_v_scroll_bar().value>0,"Down arrow scrolls a long note")
	hud.show_journal("Другая запись","Короткая заметка.","НАХОДКИ")
	for frame in 8:
		await process_frame
		if not reader.get_v_scroll_bar().visible:
			break
	check(reader.get_v_scroll_bar().value==0 and not reader.get_v_scroll_bar().visible,"New entries start at the top and short notes hide the scrollbar")
	await tap(KEY_J)
	game.finish_shift(true)
	check(game.hud.menu_art.visible and game.hud.ending_stamp.visible and game.sound.music.playing and game.sound.music.stream==game.sound.END_THEME,"The victory screen has its own illustration and soundtrack")
	DirAccess.remove_absolute(prefs.path)
	print("GAME POLISH: %d/%d" % [checks-failures, checks])
	game.queue_free()
	await create_timer(.25).timeout
	quit(0 if failures==0 else 1)
