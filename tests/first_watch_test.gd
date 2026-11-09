extends SceneTree
## The real interactions, save state, and both branches of the first watch.
var game: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	checks += 1
	if value:
		print("PASS: ",title)
	else:
		failures += 1
		push_error("FAIL: "+title)

func station(id: String) -> Area3D:
	for item in game.stations:
		if item.station_id == id:
			return item
	return null

func use_station(id: String) -> bool:
	var item := station(id)
	game.player.position = game.building_interiors.actions.get(id,item.position)
	return game.attempt_interaction(item)

func prepare() -> void:
	game.start_shift()
	game.hours_per_second = 0
	check(use_station("fuel") and use_station("beacon"), "Day one uses a real canister to power the beacon")
	check(game.campaign.target_id()=="lighthouse_lens", "The map points to the tower door after the generator")
	for i in 3:
		use_station("wood")
	check(use_station("workbench") and not game.campaign.day_complete(), "The lens inspection is required even after reinforcing the cabin")
	game.set_lighthouse_interior(true)
	game.player.position = game.LIGHTHOUSE_INTERIOR.ORIGIN + game.LIGHTHOUSE_INTERIOR.polar(1.15,.8,game.LIGHTHOUSE_INTERIOR.TOP)
	game.lighthouse_action()
	check(game.campaign.day_complete() and "c:1:2" in game.journal_entries,"Inspection at the powered lens records the warning")
	game.set_lighthouse_interior(false)
	check(not use_station("shelter"), "The first watch starts at the indoor bunk")
	game.set_building_interior("cabin")
	check(use_station("shelter") and game.campaign.state.night, "The bunk starts the authored night")
	check(not use_station("shelter"), "The bunk cannot skip the night")
	game.spawn_night()
	check(game.enemies.is_empty(), "No enemy appears before the scheduled cue")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.save_path = "user://automated_first_watch.json"
	game.set_process(false)
	prepare()
	var campaign = game.campaign
	check(not use_station("radio") and not game.journal_open,"The receiver stays quiet before its cue")
	campaign.advance(2.1)
	check(campaign.target_id()=="radio" and use_station("radio") and campaign.state.first_radio and not game.journal_open,"Tuning the receiver reveals the warehouse clue without pausing the scene")
	campaign.advance(4.1)
	check(campaign.first_window_strength()>.5 and game.enemies.size()==1 and game.enemies[0].passive,"The window and passive exterior shadow are revealed at the same moment")
	var saved_at: float = campaign.state.night_clock
	check(game.save_game(true) and game.load_game() and game.building_interiors.active=="cabin" and is_equal_approx(campaign.state.night_clock,saved_at) and campaign.state.first_radio,"A mid-watch save restores room, radio and apparition timing")
	game.spawn_night()
	check(game.enemies.size()==1,"Reload restores one exterior actor")
	game.player.lantern_on = false
	campaign.advance(4)
	check(not campaign.state.event_done,"Waiting in the dark does not complete the watch")
	game.player.lantern_on = true
	campaign.advance(4)
	check(campaign.state.first_route=="inside" and campaign.state.event_done,"Waiting by the lit lantern completes the indoor route")
	check(use_station("shelter") and game.day==2 and campaign.journal_entry("n:1").text.contains("переждал") and campaign.target_id()=="tools","Dawn records the choice and points to the warehouse")
	prepare()
	campaign.advance(6.2)
	campaign.advance(4)
	game.set_building_interior("")
	check(use_station("beacon") and campaign.state.first_route=="outside" and campaign.state.event_done,"Checking the running generator remains a choice after waiting inside")
	check(not use_station("shelter"),"The exterior check still requires returning to the bunk")
	game.set_building_interior("cabin")
	campaign.advance(8)
	check(use_station("shelter") and game.day==2 and campaign.journal_entry("n:1").text.contains("вышел проверить") and campaign.journal_entry("n:1").text.contains("записка"),"The exterior route leaves a different entry and supplies the unheard clue")
	game.start_shift()
	var old := {"marks":{"0":true,"1":true},"day":1,"night":true,"night_clock":10,"cue":3,"event_done":true}
	campaign.restore(old)
	check(campaign.state.marks.has("2") and campaign.state.first_route=="inside","A pre-update first-night save remains completable")
	if FileAccess.file_exists(game.save_path):
		DirAccess.remove_absolute(game.save_path)
	print("FIRST WATCH: %d/%d" % [checks-failures,checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
