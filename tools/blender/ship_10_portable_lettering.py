import bpy
source=bpy.data.collections["SV_SOURCE_EDITABLE"]
dg=bpy.context.evaluated_depsgraph_get()
count=0
for obj in list(source.objects):
    if obj.type!="FONT":continue
    data=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    old_name=obj.name
    new=bpy.data.objects.new(old_name+"_portable",data)
    source.objects.link(new)
    new.parent=obj.parent
    new.matrix_world=obj.matrix_world.copy()
    new["assembly"]=obj.get("assembly","Equipment")
    bpy.data.objects.remove(obj,do_unlink=True)
    new.name=old_name
    count+=1
bpy.ops.wm.save_as_mainfile(filepath=r"C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper\assets\source_blender\coastal_vessel\A37_coastal_vessel_v01.blend",compress=True)
print("PORTABLE_SOURCE_LETTERING",count,"text objects converted inside Blender; GLB already contains the same mesh lettering")
