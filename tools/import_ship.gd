@tool
extends EditorScenePostImport
## Rendering preparation only: the mesh, UVs and PBR maps come from Blender.
func _post_import(scene):
	var textures := {}
	var materials := {}
	for node in scene.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var material = node.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D or materials.has(material.get_instance_id()):
				continue
			materials[material.get_instance_id()] = true
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			for slot in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_ROUGHNESS]:
				var texture: Texture2D = material.get_texture(slot)
				if texture == null:
					continue
				var key := str(texture.get_instance_id())+str(slot==BaseMaterial3D.TEXTURE_NORMAL)
				if not textures.has(key):
					var pixels := texture.get_image()
					if not pixels.has_mipmaps():
						pixels.generate_mipmaps(slot==BaseMaterial3D.TEXTURE_NORMAL)
					var filtered := ImageTexture.create_from_image(pixels)
					filtered.resource_name = texture.resource_name
					textures[key] = filtered
				material.set_texture(slot,textures[key])
	return scene
