extends SceneTree
var checks := 0
var failures := 0
var game: Node3D
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS: ",title)
	else:
		failures += 1
		push_error("FAIL: "+title+" at "+str(game.player.position if game != null else Vector3.ZERO))
func walk(code: Key, target: float, max_frames: int = 180) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	var axis := 0 if code in [KEY_A,KEY_D] else 2
	var positive := code in [KEY_S,KEY_D]
	for frame in max_frames:
		await physics_frame
		if (positive and game.player.position[axis]>=target) or (not positive and game.player.position[axis]<=target):
			break
	print("RADIO_WALK code=",code," target=",target," position=",game.player.position)
	for i in game.player.get_slide_collision_count():
		var hit: KinematicCollision3D = game.player.get_slide_collision(i)
		if hit.get_normal().y<.7:print("RADIO_WALK_OBSTACLE ",hit.get_collider().get_path())
	key.pressed = false
	Input.parse_input_event(key)
	for frame in 8:await physics_frame
func run() -> void:
	var packed = load("res://assets/models/radio_station/radio_station_v01.glb")
	check(packed is PackedScene,"Radio GLB imports as a native Godot scene")
	if not packed is PackedScene:
		quit(1)
		return
	var asset: Node3D = packed.instantiate()
	root.add_child(asset)
	await process_frame
	var meshes := asset.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==9,"Nine radio assemblies survive export, including repair variants")
	var triangles := 0
	var invalid_normals := 0
	var missing_uv := 0
	var missing_mips := 0
	var oversize := 0
	var normal_maps := 0
	var native_materials := true
	for node in meshes:
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size()/3 if not indices.is_empty() else verts.size()/3
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in normals:
				if not normal.is_finite() or normal.length_squared()<.8:invalid_normals+=1
			var mat = node.mesh.surface_get_material(surface)
			native_materials = native_materials and mat is StandardMaterial3D
			if mat is StandardMaterial3D:
				if mat.normal_enabled and mat.normal_texture != null:normal_maps+=1
				if mat.albedo_texture != null:
					var pixels: Image = mat.albedo_texture.get_image()
					if not pixels.has_mipmaps():missing_mips+=1
					if pixels.get_width()>1024 or pixels.get_height()>1024:oversize+=1
					var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					if uv.size()!=verts.size():missing_uv+=1
	check(native_materials and normal_maps>=3,"Plaster, steel and brick use native PBR with normal maps")
	check(missing_uv==0 and invalid_normals==0,"Radio export preserves usable UVs and normalized normals")
	check(missing_mips==0 and oversize==0,"Textures use mipmaps and stay within the 1024px budget")
	check(triangles>0 and triangles<70000,"Radio station and antenna stay below 70k triangles")
	var aerial: MeshInstance3D = asset.find_child("RS_Antenna",true,false)
	check(aerial.get_aabb().end.y>10.0 and aerial.get_aabb().end.y<10.2,"Metre scale and vertical antenna axis survive glTF export")
	check(asset.find_children("*","Camera3D",true,false).is_empty() and asset.find_children("*","Light3D",true,false).is_empty(),"Studio camera, lights and ground are excluded from the game GLB")
	asset.queue_free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_shift()
	game.hours_per_second = 0
	game.hour = 14
	game.player.movement_yaw = 0
	game.save_path = "user://automated_blender_radio_test.json"
	var coast: Node3D = game.world.get_node("NorthernCoast")
	var outpost: Node3D = coast.get_node("RadioOutpost")
	var visual: Node3D = outpost.get_node("BlenderVisual")
	check(outpost.position.is_equal_approx(Vector3(-12,1,-39.5)),"Blender radio is installed at the established map location")
	check(not coast.get_node("RadioHut").visible and not coast.get_node("AntennaMast").visible,"Prototype hut and mast visuals are replaced")
	check(coast.get_node("RadioHut/Collision").collision_layer==1 and coast.get_node("RadioConsole/Collision").collision_layer==1,"Original hut and console physical bodies stay active")
	check(visual.find_child("RS_PanelFault",true,false).visible and not visual.find_child("RS_PanelOnline",true,false).visible and not visual.find_child("RS_BatteryInstalled",true,false).visible,"Unrepaired transmitter shows the warning state and empty battery bay")
	check(preload("res://scripts/radio_visual.gd").install(coast) and coast.find_children("RadioOutpost","Node3D",false,false).size()==1,"Repeated installation does not duplicate the outpost")
	var station: Area3D = coast.get_node("Station_transmitter")
	game.player.position = Vector3(-12,1.15,-33.5)
	game.player.velocity = Vector3.ZERO
	for frame in 15:await physics_frame
	await walk(KEY_W,-36.5,100)
	print("RADIO_APPROACH ",game.player.position)
	check(game.player.position.z< -35.5 and game.player.position.z> -36.1 and game.player.is_on_floor() and game.health==100,"Physical approach reaches the console without penetrating the battery shelf")
	game.update_nearest()
	check(game.nearest_station==station,"Transmitter is selected when approached on foot")
	check(not game.attempt_interaction(station) and not game.expedition.state.signal,"Day-one transmitter interaction cannot bypass the campaign gate")
	game.day = 4
	game.expedition.state.last_dawn = 4
	game.expedition.state.tools = true
	game.expedition.state.scrap = 4
	check(not game.attempt_interaction(station) and int(game.expedition.state.scrap)==4,"Repair without the salvaged battery cannot consume parts")
	var battery: Area3D = coast.get_node("Station_battery")
	game.player.position = battery.position+Vector3(0,.15,.5)
	game.player.velocity = Vector3.ZERO
	check(game.attempt_interaction(battery) and game.expedition.state.battery and not coast.get_node("SalvageBattery").visible,"Existing wreck interaction still supplies the transmitter battery")
	game.player.position = Vector3(-12,1.1,-35.6)
	game.player.velocity = Vector3.ZERO
	check(game.attempt_interaction(station) and game.expedition.state.signal and int(game.expedition.state.scrap)==2,"Repair uses the existing battery/tools gate and exactly two parts")
	check(not visual.find_child("RS_PanelFault",true,false).visible and visual.find_child("RS_PanelOnline",true,false).visible and visual.find_child("RS_BatteryInstalled",true,false).visible,"Successful repair installs the visible battery and lights the ready panel")
	check(not game.attempt_interaction(station) and int(game.expedition.state.scrap)==2,"Repeated radio contact does not charge repair resources again")
	check(game.save_game(),"Radio repair can be saved through the existing save format")
	game.expedition.state.signal = false
	game.expedition.update_visuals()
	check(game.load_game() and game.expedition.state.signal and visual.find_child("RS_BatteryInstalled",true,false).visible,"Loading restores the radio state and installed battery visual")
	# Walk a complete circuit around the hut, including the aisle beside the new mast.
	await walk(KEY_S,-34.8)
	# Leave room for normal movement braking and the existing signpost at (-8, -35).
	await walk(KEY_D,-9.0)
	await walk(KEY_W,-42.3)
	check(game.player.position.x> -9.3 and game.player.position.x< -8.4 and game.player.position.z< -42.0,"Player can pass the east side of the radio hut")
	await walk(KEY_A,-14.7)
	check(game.player.position.x< -14.8 and game.player.position.z< -42.0 and game.player.is_on_floor(),"Player can walk behind the station")
	await walk(KEY_S,-35.1)
	check(game.player.position.z> -35.4 and game.player.position.x< -14.8 and game.player.is_on_floor(),"Mast base and guy wires leave a usable west-side passage")
	await walk(KEY_D,-12)
	check(game.player.position.x> -12.3 and game.player.is_on_floor() and game.health==100,"Full radio-station circuit has no falls or collision traps")
	game.start_shift()
	check(not game.expedition.state.signal and visual.find_child("RS_PanelFault",true,false).visible and not visual.find_child("RS_BatteryInstalled",true,false).visible,"Starting a new game resets the repaired radio to its fault state")
	print("RADIO_ASSET_METRICS triangles=",triangles," meshes=",meshes.size()," normal_surfaces=",normal_maps)
	print("RESULT: ",checks-failures,"/",checks," radio asset checks passed")
	game.queue_free()
	await create_timer(.2).timeout
	quit(0 if failures==0 else 1)
