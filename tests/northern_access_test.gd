extends SceneTree
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: "+description+" at "+str(game.player.position))

func walk(target: Vector3, code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	var axis := 0 if code in [KEY_A,KEY_D] else 2
	var positive := code in [KEY_D,KEY_S]
	for i in 480:
		await physics_frame
		if positive and game.player.position[axis]>=target[axis]-0.1 or not positive and game.player.position[axis]<=target[axis]+0.1:
			break
	key.pressed = false
	Input.parse_input_event(key)
	for i in 8: await physics_frame

func place(at: Vector3) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	for i in 20: await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_shift()
	game.hours_per_second = 0
	game.player.movement_yaw = 0
	await place(Vector3(0,1.3,-10))
	await walk(Vector3(0,1,-20.7),KEY_W)
	check(game.player.position.z<-20,"Original island connects to northern peninsula on foot")
	check(game.player.is_on_floor() and game.health==100,"Northern crossing has no falls or water damage")
	await place(Vector3(7,1.3,-26))
	await walk(Vector3(7,1,-31.5),KEY_W)
	check(game.player.position.z<-31,"Warehouse doorway gives access to parts")
	await walk(Vector3(9,1,-31.5),KEY_D)
	check(game.player.position.x>8.7,"Tools can be approached inside warehouse")
	await walk(Vector3(7,1,-31.5),KEY_A)
	await walk(Vector3(7,1,-26),KEY_S)
	check(game.player.position.z>-26.3,"Warehouse can be exited without collision traps")
	for lane in [-20.7,-21.3]:
		await place(Vector3(-22,1.3,lane))
		await walk(Vector3(-33,1,lane),KEY_A)
		check(game.player.position.x<-32.6,"Gangplank allows boarding, lane "+str(lane))
		check(game.player.is_on_floor() and game.health==100,"Ship deck supports passenger without water damage")
		await walk(Vector3(-22,1,lane),KEY_D)
		check(game.player.position.x>-22.3,"Gangplank allows returning to island")
	await place(Vector3(-33,1.3,-21))
	await walk(Vector3(-33,1,-26.8),KEY_W)
	check(game.player.position.z<-26.5,"Helm is accessible across ship deck")
	var helm: Area3D = game.world.get_node("NorthernCoast/Station_ship_helm")
	check(game.player.position.distance_to(helm.position)<2.5,"Helm is inside usable interaction distance")
	check(game.player.is_on_floor() and game.health==100,"All northern walking routes preserve player health")
	print("RESULT: ",checks-failures,"/",checks," northern access checks passed")
	game.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures==0 else 1)
