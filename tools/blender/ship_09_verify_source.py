import bpy,json
path=r"C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper\assets\source_blender\coastal_vessel\A37_coastal_vessel_v01.blend"
bpy.ops.wm.open_mainfile(filepath=path)
images=[i for i in bpy.data.images if i.name.startswith("SV_")]
report={"source_reopened":True,"blender":bpy.app.version_string,"editable_source_objects":len(bpy.data.collections["SV_SOURCE_EDITABLE"].objects),"packed_texture_count":len(images),"all_textures_packed":all(i.packed_file is not None for i in images),"texture_sizes":{i.name:list(i.size) for i in images},"units":bpy.context.scene.unit_settings.system,"separate_game_export_collection":"SV_GAME_EXPORT" in bpy.data.collections}
out=r"C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper\docs\art\coastal_vessel\source-roundtrip.json"
with open(out,"w",encoding="utf-8") as f:json.dump(report,f,ensure_ascii=False,indent=2)
assert report["all_textures_packed"] and len(images)==12
print("SOURCE_ROUNDTRIP_PASS",json.dumps(report,ensure_ascii=False))
