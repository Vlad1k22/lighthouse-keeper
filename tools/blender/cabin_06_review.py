import bpy, json
from pathlib import Path
project=Path(r'C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper')
path=project/'assets/source_blender/keeper_cabin/A04_keeper_cabin_v01.blend'
# Reopen the actual saved source, without relying on an in-memory construction namespace.
bpy.ops.wm.open_mainfile(filepath=str(path))
packed=[img for img in bpy.data.images if img.packed_file]
assert len(packed)==9, 'All nine PBR maps must be packed'
assert not any(obj.type=='FONT' for obj in bpy.data.objects), 'Source lettering must be portable mesh geometry'
assert bpy.data.collections.get('KC_SOURCE_EDITABLE')
assert bpy.data.collections.get('KC_GAME_EXPORT')
report={'source_reopened':True,'packed_textures':len(packed),'external_texture_files_required':False,
        'source_objects':len(bpy.data.collections['KC_SOURCE_EDITABLE'].objects),
        'font_objects':0,'blender_version':bpy.app.version_string,'front':'Blender -Y -> Godot +Z'}
(project/'docs/art/keeper_cabin/source-roundtrip.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('CABIN_SOURCE_ROUNDTRIP_OK',json.dumps(report))
bpy.context.scene.render.filepath=str(project/'docs/art/keeper_cabin/blender-beauty.png')
bpy.ops.render.render(write_still=True)
print('CABIN_FINAL_RENDER_OK')
