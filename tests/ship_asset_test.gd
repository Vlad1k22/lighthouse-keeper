extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, title: String) -> void:
	checks += 1
	if condition: print("PASS: ",title)
	else:
		failures += 1
		push_error("FAIL: "+title)
func run() -> void:
	var packed = load("res://assets/models/coastal_vessel/coastal_vessel_v01.glb")
	check(packed is PackedScene,"Blender GLB imports as a native Godot PackedScene")
	if not packed is PackedScene:
		quit(1)
		return
	var asset: Node3D = packed.instantiate()
	root.add_child(asset)
	await process_frame
	var meshes := asset.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==10,"Ten export assemblies survive import")
	var triangles := 0
	var textured := 0
	var pbr_normal := 0
	var invalid_normals := 0
	var missing_uv := 0
	var missing_mipmaps := 0
	var types_ok := true
	for node in meshes:
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size()/3 if not indices.is_empty() else verts.size()/3
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in normals:
				if not normal.is_finite() or normal.length_squared()<0.8: invalid_normals+=1
			var mat = node.mesh.surface_get_material(surface)
			types_ok = types_ok and mat is StandardMaterial3D
			if mat is StandardMaterial3D:
				if mat.albedo_texture != null:
					textured += 1
					if not mat.albedo_texture.get_image().has_mipmaps(): missing_mipmaps+=1
					var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					if uv.size()!=verts.size(): missing_uv+=1
				if mat.normal_enabled and mat.normal_texture != null:pbr_normal+=1
	check(types_ok,"Materials import as StandardMaterial3D without custom Blender shaders")
	check(textured>=4 and pbr_normal>=4,"Base-color and normal maps are present in imported materials")
	check(missing_uv==0,"Every textured surface retains UV coordinates")
	check(missing_mipmaps==0,"PBR albedo textures have mipmaps for the isometric camera")
	check(invalid_normals==0,"Imported normals are finite and normalized")
	check(triangles>20000 and triangles<450000,"Hero model remains inside the declared geometry budget")
	var hull: MeshInstance3D = asset.find_child("SV_Hull",true,false)
	var bounds := hull.get_aabb()
	check(bounds.size.x>6.5 and bounds.size.x<7.5,"Hull width remains compatible with existing physics")
	check(bounds.size.z>17.5 and bounds.size.z<18.5,"Metres and Blender-to-Godot forward axis survive export")
	check(asset.find_children("*","Camera3D",true,false).is_empty() and asset.find_children("*","Light3D",true,false).is_empty(),"Presentation camera, sea and lights are excluded from the game asset")
	asset.queue_free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_demo()
	game.hours_per_second = 0
	game.save_path = "user://automated_blender_ship_test.json"
	var vessel: Node3D = game.world.get_node("NorthernCoast/CoastalVessel")
	var visual: Node3D = vessel.get_node("BlenderVisual")
	check(visual != null,"Blender model appears inside the playable vessel")
	check(not vessel.get_node("WalkableDeck").visible,"Procedural deck visual is hidden without deleting collision")
	check(not vessel.find_children("*","StaticBody3D",true,false).is_empty(),"Original tested collision bodies are preserved")
	check(visual.find_child("SV_HullDamage",true,false).visible and not visual.find_child("SV_HullPatch_Repaired",true,false).visible,"Unrepaired ship shows only its damaged state")
	var station: Area3D = game.world.get_node("NorthernCoast/Station_ship_hull")
	game.player.position = station.position+Vector3(0,.3,.5)
	check(game.attempt_interaction(station),"Existing repair interaction works with the Blender visual")
	check(not visual.find_child("SV_HullDamage",true,false).visible and visual.find_child("SV_HullPatch_Repaired",true,false).visible,"Repair switches the Blender-authored damage variants")
	game.day=6
	game.expedition.state.last_dawn=6
	station=game.world.get_node("NorthernCoast/Station_ship_engine")
	game.player.position=station.position+Vector3(0,.3,.5)
	check(game.attempt_interaction(station) and visual.find_child("SV_EngineReady",true,false).visible,"Engine repair enables the imported engine indicator")
	check(game.save_game(),"Save accepts a repaired Blender vessel")
	game.expedition.state.hull=false
	game.expedition.update_visuals()
	check(game.load_game(),"Load restores the existing save with the new visual")
	visual=game.world.get_node("NorthernCoast/CoastalVessel/BlenderVisual")
	check(visual.find_child("SV_HullPatch_Repaired",true,false).visible and visual.find_child("SV_EngineReady",true,false).visible,"Load restores both Blender repair states")
	print("SHIP_ASSET_METRICS triangles=",triangles," meshes=",meshes.size()," textured_surfaces=",textured," normal_mapped_surfaces=",pbr_normal)
	print("RESULT: ",checks-failures,"/",checks," Blender export checks passed")
	game.queue_free()
	await create_timer(.3).timeout
	quit(0 if failures==0 else 1)
