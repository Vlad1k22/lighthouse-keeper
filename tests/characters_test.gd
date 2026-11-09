extends SceneTree
const VISUAL = preload("res://scripts/character_visual.gd")
const PLAYER = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func input(code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	input(code,true)
	await frames(2)
	input(code,false)

func place(at: Vector3) -> void:
	game.player.position = at
	game.player.reset_motion()
	await frames(18)

func run() -> void:
	for kind in ["keeper","shadow","drowned"]:
		var packed := load(VISUAL.MODELS[kind]) as PackedScene
		check(packed != null,kind+" GLB imports")
		if packed == null:
			quit(1)
			return
		var model := packed.instantiate()
		var rigs := model.find_children("*","Skeleton3D",true,false)
		var anim := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		var list := ["idle","walk","run","jump","fall","land","interact","lantern","cast","fish_hold","hit"] if kind=="keeper" else ["idle","walk","run","watch","attack","recoil"]
		check(rigs.size()==1 and rigs[0].get_bone_count()>=17,kind+" has a complete skinned skeleton")
		var valid := anim != null
		for clip in list:
			valid = valid and anim.has_animation(clip) and anim.get_animation(clip).get_track_count()>4
		check(valid,kind+" imported all named clips with bone tracks")
		model.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled=false
	game.start_shift()
	game.hours_per_second=0
	game.player.movement_yaw=0
	await place(Vector3(0,1.15,2))
	var player = game.player
	check(player.motion.skeleton != null and player.motion.current=="idle","Keeper idles using the imported Blender rig")
	check(is_instance_valid(player.lantern_socket) and player.get_node("HandLantern").global_position.distance_to(player.lantern_socket.global_position)<.12,"Godot light follows the animated lantern bone")
	input(KEY_F,true)
	await frames(3)
	input(KEY_F,false)
	check(not player.lantern_on and not player.motion.lantern_glow.visible and player.motion.current=="lantern","F animates the hand and switches off the real light")
	player.lantern_on=true
	var y0: float=player.position.y
	var max_height := 0.0
	var saw_fall := false
	var saw_land := false
	player.stamina=100
	input(KEY_SPACE,true)
	await frames(3)
	check(player.jump_in_progress and player.motion.current=="jump" and absf(player.stamina-82)<.3,"Space takes off and spends exactly 18 stamina")
	var start_velocity: float = player.velocity.y
	await tap(KEY_M)
	var paused_position: Vector3 = player.position
	var paused_time: float = player.motion.animator.current_animation_position
	var paused_velocity: float = player.velocity.y
	await frames(12)
	check(game.paused and player.position.is_equal_approx(paused_position) and is_equal_approx(player.motion.animator.current_animation_position,paused_time) and paused_velocity>0,"Map freezes the airborne pose and keeps takeoff velocity")
	await tap(KEY_M)
	check(not game.paused and player.velocity.y<start_velocity and player.velocity.y>0,"Closing the map resumes the same jump")
	for i in 65:
		max_height = maxf(max_height,player.position.y-y0)
		saw_fall = saw_fall or player.motion.current=="fall"
		saw_land = saw_land or player.motion.current=="land"
		if i in [6,43]:
			input(KEY_SPACE,true,true)
		await frames(1)
	input(KEY_SPACE,false)
	check(max_height>.49 and max_height<.69 and saw_fall and saw_land,"Jump has a short arc, falling pose and landing pose")
	check(player.is_on_floor() and not player.jump_in_progress and absf(player.position.y-y0)<.04,"Holding Space does not bounce after landing")
	player.stamina=0
	await tap(KEY_SPACE)
	await frames(5)
	check(player.is_on_floor() and not player.jump_in_progress,"Exhaustion prevents a jump")
	player.stamina=100
	var step_body := StaticBody3D.new()
	var step_collider := CollisionShape3D.new()
	var step_box := BoxShape3D.new()
	step_box.size=Vector3(.22,.27,1.1)
	step_collider.shape=step_box
	step_body.add_child(step_collider)
	game.add_child(step_body)
	step_body.position=Vector3(1.05,y0+.135,2)
	await place(Vector3(0,1.15,2))
	input(KEY_D,true)
	await frames(10)
	var x0: float=player.position.x
	await tap(KEY_SPACE)
	var far_x: float=player.position.x
	var max_air_speed := 0.0
	for i in 29:
		if player.jump_in_progress:
			max_air_speed=maxf(max_air_speed,Vector2(player.velocity.x,player.velocity.z).length())
			far_x=maxf(far_x,player.position.x)
		await frames(1)
	input(KEY_D,false)
	await frames(14)
	check(player.position.x>1.28 and player.is_on_floor(),"Short jump clears a low obstacle and lands on the island")
	check(far_x-x0<2.35 and max_air_speed<=PLAYER.AIR_SPEED+.02,"Air control cannot extend the jump into a long dash")
	step_body.queue_free()
	await place(Vector3(-33,1.22,-21))
	await tap(KEY_SPACE)
	await frames(42)
	check(player.is_on_floor() and absf(player.position.x+33)<.2 and game.health==100,"Jumping on the ship deck lands safely")
	await place(Vector3(-30,1.25,-21))
	await tap(KEY_SPACE)
	await frames(42)
	check(player.is_on_floor() and absf(player.position.x+30)<.2 and game.health==100,"Jumping on the gangplank keeps the original collision support")
	await place(Vector3(23.3,1.25,5.4))
	game.start_fishing()
	await tap(KEY_SPACE)
	await frames(5)
	check(game.fishing.is_open() and not player.jump_in_progress and not player.enabled,"Space controls fishing without starting a jump")
	game.close_fishing()
	await place(Vector3(23.9,1.24,5.4))
	input(KEY_D,true)
	await frames(8)
	await tap(KEY_SPACE)
	await frames(82)
	input(KEY_D,false)
	await frames(10)
	check(game.health<100 and player.position.x<10 and player.is_on_floor(),"Jumping out to sea still invokes the water recovery")
	await place(Vector3(-3,1.15,3))
	game.health=100
	game.hour=22
	game.night_spawned=true
	player.lantern_on=false
	game.spawn_shadow(Vector3(-3,1.08,3.78))
	var enemy = game.enemies.back()
	await frames(9)
	check(enemy.motion.current=="attack" and game.health==100,"Shadow telegraphs its hit before dealing damage")
	player.lantern_on=true
	await frames(24)
	check(enemy.attack_time<=0 and game.health==100,"Lantern cancels the shadow windup")
	game.clear_enemies()
	await frames(2)
	player.lantern_on=false
	game.spawn_shadow(Vector3(-3,1.08,3.80),"drowned")
	var heavy = game.enemies.back()
	await frames(21)
	check(heavy.kind=="drowned" and heavy.motion.current=="attack" and game.health==100,"Drowned plays its own slower windup")
	await frames(15)
	check(game.health<=83 and player.motion.current=="hit","Drowned deals stronger damage on impact and the keeper flinches")
	game.queue_free()
	await process_frame
	print("RESULT: %d/%d character checks passed" % [checks-failures,checks])
	quit(1 if failures else 0)
