extends SceneTree
## Full 30-day economy/story run through real station handlers. No inventory injection.
var game: Node
var checks := 0
var failures := 0
var supplies := {"wood":0,"scrap":0,"fuel":0,"cache":0}
func _initialize() -> void:call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:
		failures+=1
		push_error("FAIL: "+title+" / day "+str(game.day))
func station(id: String) -> Area3D:
	for item in game.stations:
		if item.station_id==id:return item
	return null
func take(id: String) -> bool:
	if game.journal_open:game.close_journal()
	var item := station(id)
	game.player.position = item.position+Vector3(0,.3,.85)
	game.player.velocity = Vector3.ZERO
	return game.attempt_interaction(item)
func reserve(cost: Dictionary) -> bool:
	for key in cost:
		for tries in 10:
			var amount: int = int(game.expedition.state.scrap) if key=="scrap" else int(game.inventory[key])
			if amount>=int(cost[key]):break
			var source: String = {"wood":"wood","scrap":"scrap","fuel":"depot"}[key]
			if not take(source):return false
			supplies[key]+=1
		var remaining: int = int(game.expedition.state.scrap) if key=="scrap" else int(game.inventory[key])
		if remaining<int(cost[key]):return false
	return true
func meals(required: int) -> bool:
	if game.food_items.size()<required and not game.expedition.state.cache:
		take("cache")
		supplies.cache+=1
	return game.food_items.size()>=required
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.save_path = "user://automated_campaign_v4.json"
	game.start_shift()
	game.hours_per_second = 0
	game.set_process(false)
	check(game.campaign.enabled and game.campaign.shifts.size()==30,"New game starts the full 30-day campaign")
	var titles := {}
	var known_ids := {}
	for item in game.stations:known_ids[item.station_id]=true
	var valid := true
	var nominal_seconds := 0.0
	for record in game.campaign.shifts:
		titles[record.title]=true
		for goal in record.goals:valid=valid and known_ids.has(goal.id)
		nominal_seconds += float(record.night.seconds)
	nominal_seconds += game.campaign.DAY_SECONDS*29
	check(titles.size()==30 and valid,"Thirty distinct shifts refer only to reachable existing stations")
	check(nominal_seconds>=1800 and nominal_seconds<2400,"Nominal 30-day clock fits approximately 30-40 minutes")
	check(not take("shelter") and not game.campaign.state.night,"Night cannot be skipped before the first objectives")
	check(not game.campaign.submit_code("314"),"Correct radio code cannot bypass the campaign before day 29")
	check(game.campaign.journal_entry("c:code").text.contains("? · ? · ?"),"Code bookmark does not reveal undiscovered fragments")
	var mid_night_snapshot := ""
	for number in range(1,31):
		check(game.day==number,"Calendar opens authored day "+str(number))
		for guard in 8:
			var index: int = game.campaign.next_index()
			if index<0:break
			var goal: Dictionary = game.campaign.entry().goals[index]
			var costs: Dictionary = goal.cost.duplicate()
			if goal.kind=="base":
				costs = {"workbench":{"wood":3},"pump":{"wood":1,"scrap":2},"transmitter":{"scrap":2},"ship_hull":{"wood":5,"scrap":2},"ship_engine":{"scrap":4},"ship_fuel":{"fuel":3},"fire":{"wood":1}}.get(goal.id,{})
			if not reserve(costs):
				check(false,"Resources remain obtainable for "+goal.title)
				quit(1)
				return
			if goal.id=="ship_stores" and not meals(3):
				check(false,"Three meals are obtainable before loading ship")
				quit(1)
				return
			if not take(goal.id):
				check(false,"Physical station accepts "+goal.title)
				quit(1)
				return
			if goal.kind=="code":
				check(game.campaign.code_open() and game.paused and not game.player.enabled,"Code entry opens a modal and freezes controls")
				var parts: int = game.expedition.state.scrap
				check(not game.campaign.submit_code("999") and not game.campaign.goal_done(0) and int(game.expedition.state.scrap)==parts,"Wrong code neither advances the story nor consumes supplies")
				var clock_before: float = game.campaign.state.day_clock
				game.hours_per_second=.055
				game._process(2)
				game.hours_per_second=0
				check(game.campaign.state.day_clock==clock_before,"Code modal pauses the campaign clock")
				var escape := InputEventKey.new()
				escape.physical_keycode=KEY_ESCAPE
				escape.keycode=KEY_ESCAPE
				escape.pressed=true
				Input.parse_input_event(escape)
				await process_frame
				await process_frame
				var escape_release: InputEventKey=escape.duplicate()
				escape_release.pressed=false
				Input.parse_input_event(escape_release)
				await process_frame
				check(not game.campaign.code_open() and not game.paused,"Esc closes code entry even while the text field has focus")
				game.open_journal()
				check(game.hud.reader_title.text=="Контрольная группа" and game.hud.reader_text.text.contains("3 · 1 · 4"),"Journal opens the collected-code bookmark without paging through every night")
				game.close_journal()
				take("transmitter")
				game.campaign.code_input.text = "314"
				var enter := InputEventKey.new()
				enter.keycode = KEY_ENTER
				enter.physical_keycode = KEY_ENTER
				enter.pressed = true
				Input.parse_input_event(enter)
				await process_frame
				await process_frame
				var enter_release: InputEventKey=enter.duplicate()
				enter_release.pressed=false
				Input.parse_input_event(enter_release)
				await process_frame
				check(game.campaign.goal_done(0) and not game.campaign.code_open() and not game.paused,"Enter submits the real radio-code UI and resumes play")
		check(game.campaign.day_complete(),"Day "+str(number)+" objectives complete using real resources")
		check(game.inventory.wood>=0 and int(game.expedition.state.scrap)>=0 and game.inventory.fuel>=0,"Day "+str(number)+" does not overdraw inventory")
		if number==30:break
		if game.hunger<25:
			check(meals(1) and game.eat(),"Available meals cover night preparation")
		if int(game.campaign.state.beacon_charge)<=0:reserve({"fuel":1})
		var fuel_for_light: int=game.inventory.fuel
		if not game.lighthouse_on:take("beacon")
		if number==2:check(game.inventory.fuel==fuel_for_light and int(game.campaign.state.beacon_charge)==2,"One can powers three nightly shifts without daily fuel grinding")
		game.player.lantern_on=true
		if number==1:
			game.player.lantern_on=false
			check(not take("shelter"),"Preparation requires the hand lantern to be on")
			game.player.lantern_on=true
		check(take("shelter") and game.campaign.state.night,"Prepared day "+str(number)+" can start its night early")
		if number in [1,4,10,29]:check(not take("shelter") and game.day==number,"Night event cannot be bypassed by repeatedly pressing E")
		var kind: String = game.campaign.entry().night.kind
		if number in [1,12,14]:
			game.spawn_night()
			check(game.enemies.size()>0 and bool(game.enemies[0].passive)==(number!=12),"Night "+str(number)+" spawns its intended passive or hostile actors")
			if number==14:
				var double: CharacterBody3D=game.enemies[0]
				check(double.has_node("Visual/Head") and double.mirroring,"Double event reuses the keeper visual and mirrors movement")
				var move := InputEventKey.new()
				move.physical_keycode=KEY_D
				move.pressed=true
				Input.parse_input_event(move)
				for frame in 12:await physics_frame
				check(absf(double.velocity.x)>.1,"Keeper movement actually moves the double")
				move.pressed=false
				Input.parse_input_event(move)
				for frame in 20:await physics_frame
				check(Vector2(double.velocity.x,double.velocity.z).length()<.01,"Double stops when the keeper stops")
		if number==17:
			game.campaign.advance(5)
			game.expedition.open_board()
			game.hours_per_second=.055
			game._process(7)
			check(game.campaign.state.night_clock==5 and not game.player.enabled,"Map pauses a live night timer with normal time speed")
			game.expedition.close_board()
			game.hours_per_second=0
			check(game.save_game(),"Unresolved blackout can be saved mid-night")
			mid_night_snapshot=FileAccess.get_file_as_string(game.save_path)
			game.campaign.state.blackout=false
			game.player.lantern_on=false
			check(game.load_game() and game.campaign.state.blackout and game.campaign.state.night_clock==5 and game.player.lantern_on,"Load restores pending blackout, night timer and lantern")
		if kind=="last":check(not take("radio") and not game.campaign.state.event_done,"Final night requires power before the confirming radio call")
		if kind in ["blackout","last"]:
			var fuel_before: int = game.inventory.fuel
			check(take("beacon") and not game.campaign.state.blackout and game.lighthouse_on and game.inventory.fuel==fuel_before,"Night "+str(number)+" power reset is interactive and does not double-charge fuel")
		if kind in ["static","false_call","last"]:check(take("radio") and game.campaign.state.event_done,"Night "+str(number)+" radio event requires the correct physical receiver")
		game.player.position=station("shelter").position+Vector3(0,.3,.5)
		for second in ceili(float(game.campaign.entry().night.seconds))+1:game.campaign.advance(1)
		check(take("shelter") and game.day==number+1 and game.campaign.state.completed_days.size()==number,"Night "+str(number)+" ends in a single persistent dawn")
	check(game.campaign.state.clearance and game.expedition.ready_to_sail(),"Only the completed month opens the real departure window")
	game.day=29
	check(not game.expedition.ready_to_sail(),"Even a fully equipped vessel cannot skip the final calendar gate")
	game.day=30
	game.campaign.ensure_day()
	check(game.campaign.journal_entry("c:9:0").text.contains("3") and game.campaign.journal_entry("c:17:0").text.contains("1") and game.campaign.journal_entry("c:26:0").text.contains("4"),"All three code fragments remain readable from journal records")
	game.campaign.advance(10000)
	check(game.day==30 and not game.finished and not game.is_night(),"Final day cannot roll into an accidental day-31 failure")
	var completed_journal: int = game.journal_entries.size()
	game.checkpoint_path="user://automated_campaign_win_checkpoint.json"
	game.checkpoints_enabled=true
	game.save_checkpoint()
	check(take("ship_helm") and game.expedition.sailing,"Day-30 helm starts the real vessel departure")
	game.expedition.advance(7)
	check(game.finished and game.hud.menu_title.text.contains("материк"),"Prepared 30-day campaign reaches its playable ending")
	game.start_or_resume()
	check(game.day==1 and not game.finished and game.campaign.enabled,"New-game button after victory starts day one rather than retrying the final day")
	# Separate checkpoint and legacy migration fixtures, without writing to a real player save.
	var legacy: Dictionary = JSON.parse_string(mid_night_snapshot)
	legacy.version=3
	legacy.erase("campaign")
	var file := FileAccess.open(game.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(game.load_game() and game.day==17 and game.campaign.enabled and game.campaign.state.completed_days.size()==16,"Version-three saves retain progress and migrate into the authored month")
	check(game.campaign.state.night and game.campaign.state.blackout and game.campaign.journal_entry("c:code").text.contains("3 · 1 · ?"),"Legacy night resumes its event and receives required archive clues instead of losing the code")
	game.day=30
	game.campaign.ensure_day()
	game.expedition.state.merge({"signal":false,"hull":false,"engine":false,"ship_fuel":false,"scrap":0,"visits":{},"daily":{}},true)
	game.inventory.fuel=0
	var emergency_parts := true
	for i in 4:emergency_parts=take("scrap") and emergency_parts
	check(emergency_parts and int(game.expedition.state.scrap)==8 and not take("scrap"),"Final-day catch-up supplies exactly the parts needed for unfinished legacy repairs")
	check(take("depot") and take("depot") and game.inventory.fuel>=3 and not take("depot"),"Final day allows filling an empty boat tank without waiting for a nonexistent next day")
	game.day=18
	game.campaign.ensure_day()
	game.hour=7
	game.health=71
	game.checkpoint_path="user://automated_campaign_checkpoint.json"
	game.checkpoints_enabled=true
	game.save_checkpoint()
	game.health=53
	game.save_game()
	var checkpoint_file := FileAccess.open(game.checkpoint_path,FileAccess.WRITE)
	checkpoint_file.store_string("{}")
	checkpoint_file.close()
	check(game.load_game() and game.day==18 and game.health==53,"Manual save restores its in-progress day")
	var manual_before := FileAccess.get_file_as_string(game.save_path)
	game.day=19
	game.health=1
	game.finish_shift(false)
	check(game.retry_day() and game.day==18 and game.health==71 and game.campaign.state.day==18,"Death retry restores the beginning of the day instead of resetting the month")
	check(FileAccess.get_file_as_string(game.save_path)==manual_before,"Automatic checkpoint leaves the manual save untouched")
	game.start_demo()
	check(not game.campaign.enabled and game.day==5,"Harbor asset demonstration remains a separate free-roam fixture")
	game.start_or_resume()
	check(game.campaign.enabled and game.day==1,"Starting a normal game after the demo restores the 30-day campaign")
	print("CAMPAIGN_METRICS nominal_seconds=",nominal_seconds," supply_interactions=",supplies," completed_journal_entries=",completed_journal)
	print("RESULT: ",checks-failures,"/",checks," campaign checks passed")
	game.queue_free()
	await create_timer(.3).timeout
	quit(0 if failures==0 else 1)
