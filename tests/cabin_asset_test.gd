extends SceneTree
var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks += 1
	if condition: print("PASS: ",title)
	else:
		failures += 1
		push_error("FAIL: "+title)

func walk_until(code: Key, target_z: float, increasing: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	for frame in 120:
		await physics_frame
		if (increasing and game.player.position.z>=target_z) or (not increasing and game.player.position.z<=target_z):
			break
	key.pressed = false
	Input.parse_input_event(key)
	for frame in 12: await physics_frame

func run() -> void:
	var packed = load("res://assets/models/keeper_cabin/keeper_cabin_v01.glb")
	check(packed is PackedScene,"Cabin GLB imports as a native Godot PackedScene")
	if not packed is PackedScene:
		quit(1)
		return
	var asset: Node3D = packed.instantiate()
	root.add_child(asset)
	await process_frame
	var meshes := asset.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==7,"Seven logical cabin assemblies survive import")
	var triangles := 0
	var missing_uv := 0
	var bad_normals := 0
	var missing_mips := 0
	var oversize_maps := 0
	var textured := 0
	var all_pbr := true
	for node in meshes:
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size()/3 if not indices.is_empty() else vertices.size()/3
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in normals:
				if not normal.is_finite() or normal.length_squared()<.8: bad_normals+=1
			var material = node.mesh.surface_get_material(surface)
			all_pbr = all_pbr and material is StandardMaterial3D
			if material is StandardMaterial3D and material.albedo_texture != null:
				textured += 1
				var image: Image = material.albedo_texture.get_image()
				if not image.has_mipmaps(): missing_mips+=1
				if image.get_width()>1024 or image.get_height()>1024: oversize_maps+=1
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				if uv.size()!=vertices.size():missing_uv+=1
	check(all_pbr,"Cabin uses native PBR materials without custom Blender shader dependencies")
	check(textured>0 and missing_uv==0,"Visible textured surfaces retain their UV coordinates")
	check(missing_mips==0,"Shared texture maps have mipmaps for the game camera")
	check(oversize_maps==0,"No imported cabin albedo exceeds the 1024px visible-surface budget")
	check(bad_normals==0,"Exported normals are finite and normalized")
	check(triangles>10000 and triangles<70000,"Cabin stays under its 70k triangle geometry budget")
	var structure: MeshInstance3D = asset.find_child("KC_Structure",true,false)
	check(structure.get_aabb().size.x>5.9 and structure.get_aabb().size.x<6.3,"Cabin metre scale matches the existing foundation")
	var door: Node3D = asset.find_child("KC_Door",true,false)
	check(door != null and door.position.is_equal_approx(Vector3(-.49,0,2.23)),"Door retains a separate hinge origin facing Godot +Z")
	check(asset.find_children("*","Camera3D",true,false).is_empty() and asset.find_children("*","Light3D",true,false).is_empty(),"Presentation camera and lights are excluded from GLB")
	asset.queue_free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Asset/collision regression fixture; story-night progression is tested separately.
	game.campaign.enabled = false
	game.start_shift()
	game.hours_per_second = 0
	game.player.movement_yaw = 0
	game.save_path = "user://automated_blender_cabin_test.json"
	var cabin: Node3D = game.world.get_node("IslandGeometry/KeeperCabin")
	check(cabin.has_node("BlenderVisual") and not cabin.get_node("TimberWalls").visible,"New cabin replaces the old visual inside the playable scene")
	check(cabin.get_node("TimberWalls/Collision").collision_layer==1 and cabin.get_node("Porch/Collision").collision_layer==1,"Original wall and porch collision remain active")
	check(cabin.get_node("ChimneySmoke").emitting and cabin.has_node("EntryLanternLight"),"Godot smoke and new entry light are present")
	check(preload("res://scripts/cabin_visual.gd").install(cabin) and cabin.find_children("BlenderVisual","Node3D",false,false).size()==1,"Repeated loading does not duplicate the cabin")
	# Actual held-key motion across the new ramp, on two lanes, without teleporting onto the porch.
	for lane in [4.78,5.22]:
		game.player.position = Vector3(lane,1.1,4.8)
		game.player.velocity = Vector3.ZERO
		for frame in 12:await physics_frame
		await walk_until(KEY_W,2.65,false)
		print("CABIN_WALK_IN ",game.player.position)
		check(game.player.position.z<3.0 and game.player.position.y>1.35 and game.player.is_on_floor(),"Player walks from island onto the porch without jumping, lane "+str(lane))
		await walk_until(KEY_S,4.65,true)
		check(game.player.position.z>4.5 and game.player.position.y<1.12 and game.health==100 and game.player.is_on_floor(),"Player returns to the island without getting stuck or hurt, lane "+str(lane))
	# Existing actions stay at their original stations, independent of the imported mesh hierarchy.
	var station: Area3D = game.world.get_node("Station_workbench")
	game.player.position = station.position+Vector3(0,.1,.3)
	game.inventory.wood = 3
	check(game.attempt_interaction(station) and game.barricade_built,"Existing workbench still builds the shelter reinforcement")
	station = game.world.get_node("Station_cook")
	game.player.position = station.position+Vector3(0,.1,.3)
	game.fish_items.append({"name":"Окунь","rarity":"common","weight":.5,"kind":"fish"})
	game.sync_provisions()
	var old_food: int = game.food_items.size()
	check(game.attempt_interaction(station) and game.food_items.size()==old_food+1,"Existing cooking action still prepares fish beside the cabin")
	station = game.world.get_node("Station_radio")
	game.player.position = station.position+Vector3(0,.1,.3)
	check(game.attempt_interaction(station) and game.journal_entries.has("radio"),"Radio beside the cabin still unlocks its story")
	game.close_journal()
	station = game.world.get_node("Station_shelter")
	game.player.position = Vector3(5,1.25,3.7)
	game.hour = 22
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	check(game.attempt_interaction(station) and game.day==2 and game.hour==7,"Sleep at the cabin entrance advances the game to the next morning")
	check(game.save_game() and game.load_game() and game.world.get_node("IslandGeometry/KeeperCabin/BlenderVisual") != null,"Existing save/load works with the Blender cabin installed")
	print("CABIN_ASSET_METRICS triangles=",triangles," meshes=",meshes.size()," textured_surfaces=",textured)
	print("RESULT: ",checks-failures,"/",checks," cabin checks passed")
	game.queue_free()
	await create_timer(.2).timeout
	quit(0 if failures==0 else 1)
