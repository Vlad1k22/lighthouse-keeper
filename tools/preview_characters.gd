extends SceneTree
## A close comparison and a real input-driven jump on the playable island.

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func capture(path: String) -> int:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png("res://docs/art/characters/"+path)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.set_process(false)
	game.hour = 15.4
	game.update_atmosphere()
	game.hud.game_ui.hide()
	game.hud.message_label.hide()
	for marker in game.world.find_children("InteractionMarker","Label3D",true,false):
		marker.hide()
	game.player.position = Vector3(-33,1.12,-21.8)
	game.player.get_node("Visual").rotation.y = PI/2
	var focus := Vector3(-33,1.98,-21.8)
	game.camera.position = focus + Vector3(11,6,3)
	game.camera.look_at(focus)
	game.camera.size = 6.4
	game.spawn_shadow(Vector3(-33,1.01,-19.8),"shadow")
	game.spawn_shadow(Vector3(-33,1.01,-23.8),"drowned")
	for enemy in game.enemies:
		enemy.passive = true
		enemy.set_physics_process(false)
		enemy.get_node("Visual").rotation.y = PI/2
		enemy.motion.play("watch",0)
		enemy.motion.tick(.4)
	await frames(30)
	var lineup := await capture("godot-characters.png")
	for enemy in game.enemies:
		enemy.hide()
	game.camera.size=4.6
	var skeleton: Skeleton3D = game.player.motion.skeleton
	var thigh := skeleton.find_bone("Thigh.L")
	var rest_pose := skeleton.get_bone_pose_rotation(thigh)
	var action := InputEventKey.new()
	action.physical_keycode=KEY_SPACE
	action.pressed=true
	Input.parse_input_event(action)
	await frames(15)
	var active_jump: bool = game.player.jump_in_progress
	var pose_delta := rest_pose.angle_to(skeleton.get_bone_pose_rotation(thigh))
	var jump_capture := await capture("godot-jump.png")
	print("CHARACTER_PREVIEW lineup=",lineup," jump_capture=",jump_capture," active_jump=",active_jump," pose=",game.player.motion.current," thigh_angle_delta=",pose_delta)
	game.queue_free()
	await process_frame
	quit(0 if lineup==OK and jump_capture==OK and active_jump and pose_delta>.10 else 1)
