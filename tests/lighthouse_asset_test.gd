extends SceneTree

const VISUAL = preload("res://scripts/lighthouse_visual.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func run() -> void:
	var packed := load(VISUAL.MODEL) as PackedScene
	check(packed != null, "Blender lighthouse imports as a native PackedScene")
	if packed == null:
		quit(1)
		return
	var model := packed.instantiate() as Node3D
	check(model.find_children("*", "MeshInstance3D", true, false).size() == 7, "Seven model assemblies survive GLB import")
	check(model.find_children("*", "Light3D", true, false).is_empty() and model.find_children("*", "Camera3D", true, false).is_empty(), "Export excludes studio lights and camera")
	var tower := model.get_node("LH_Tower") as MeshInstance3D
	var body := tower.get_aabb()
	var stone := tower.mesh.surface_get_material(0) as StandardMaterial3D
	check(body.size.y > 9.3 and body.size.y < 9.6 and body.size.x > 2.9 and body.size.x < 3.1, "Tower scale fits the original collision")
	check(stone.albedo_texture != null and stone.normal_enabled and stone.normal_texture != null and stone.roughness_texture != null, "Stone color, roughness and normal maps import")
	check(stone.albedo_texture.get_image().has_mipmaps() and stone.normal_texture.get_image().has_mipmaps(), "Tower maps have mipmaps")
	var lens_mesh := model.get_node("LH_Lens") as MeshInstance3D
	check(absf(lens_mesh.get_aabb().get_center().y - 10.65) < .05, "Fresnel optic is centred on the existing beacon beam")
	model.free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.player.movement_yaw = 0
	var beacon = game.beacon
	var pivot := beacon.get_node("BeamPivot") as Node3D
	var station := game.world.get_node("Station_beacon") as Area3D
	check(VISUAL.install(beacon) and beacon.find_children("BlenderVisual","Node3D",false,false).size() == 1, "Installed visual does not duplicate on repeated setup")
	check(not beacon.get_node("Foundation").visible and beacon.get_node("Foundation/Collision").collision_layer == 1, "Original foundation hides visually but keeps collision")
	check(beacon.lens_material != null and not beacon.lens_material.emission_enabled and beacon.lens_material.albedo_color != beacon.lens_color and not pivot.visible, "Lens and beam start off together")
	var pickup := game.world.get_node("Station_fuel") as Area3D
	game.player.position = pickup.position + Vector3.UP * .15
	check(game.attempt_interaction(pickup) and game.inventory.fuel == 1, "Campaign fuel pickup still works")
	game.player.position = station.position + Vector3(0,.15,3)
	game.player.velocity = Vector3.ZERO
	for i in 8: await physics_frame
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in 110:
		await physics_frame
		if game.player.position.z < station.position.z + 1.2:
			break
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	for i in 5: await physics_frame
	check(game.player.position.z < station.position.z + 1.3 and game.player.is_on_floor(), "Player can walk up to the original generator")
	check(game.attempt_interaction(station) and game.inventory.fuel == 0 and game.campaign.state.beacon_charge == 3, "Generator consumes fuel and charges the campaign beacon")
	check(beacon.lens_material.emission_enabled and beacon.lens_material.albedo_color == beacon.lens_color and pivot.visible and beacon.get_node("Lantern").light_energy == 3.5, "Power lights the lens, beam and Godot lantern together")
	var old_angle := pivot.rotation.y
	for i in 8: await process_frame
	check(not is_equal_approx(old_angle, pivot.rotation.y), "The existing beam still rotates")
	beacon.set_powered(false)
	check(not beacon.lens_material.emission_enabled and not pivot.visible, "Power loss switches off both the Blender optic and Godot beam")
	game.queue_free()
	await process_frame
	print("RESULT: %d/%d lighthouse asset checks passed" % [checks - failures,checks])
	quit(1 if failures else 0)
