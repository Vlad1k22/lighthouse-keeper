import bpy
globals().update(bpy.app.driver_namespace["SV_BUILD"])
M["SV_Glass"].node_tree.nodes.get("Principled BSDF").inputs["Alpha"].default_value=.32
M["SV_Glass"].diffuse_color=(.12,.20,.20,.32)
# Export the already prepared, triangulated assemblies; no scene reconstruction.
EX.hide_viewport=False
EX.hide_render=False
bpy.ops.object.select_all(action="DESELECT")
for obj in EX.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=eroot
bpy.ops.export_scene.gltf(**{k:v for k,v in opts.items() if k in properties})
EX.hide_viewport=True
EX.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+"/A37_coastal_vessel_v01.blend",compress=True)
print("GLASS_FIXED_ALPHA_AND_EXPORTED",len(EX.objects),"game nodes")
