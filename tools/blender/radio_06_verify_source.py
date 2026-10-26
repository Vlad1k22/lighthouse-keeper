"""Read the saved source in the active asset scene and verify portability via MCP."""
import bpy, json, os
project=r'C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper'
path=project+'/assets/source_blender/radio_station/A26_radio_station_v01.blend'
bpy.ops.wm.open_mainfile(filepath=path)
textures=[img for img in bpy.data.images if img.packed_file]
assert len(textures)==9
assert not any(obj.type=='FONT' for obj in bpy.data.objects)
assert bpy.data.collections.get('RS_SOURCE_EDITABLE') and bpy.data.collections.get('RS_GAME_EXPORT')
assert all(max(img.size)<=1024 for img in textures)
report={'source_reopened':True,'blender':bpy.app.version_string,'packed_textures':len(textures),
        'font_objects':0,'external_texture_files_required':False,'source_objects':len(bpy.data.collections['RS_SOURCE_EDITABLE'].objects),
        'source_size_bytes':os.path.getsize(path),'modeling_protocol':'MCP stdio / mcp-for-blender 2.2.4'}
with open(project+'/docs/art/radio_station/source-roundtrip.json','w',encoding='utf-8') as f:json.dump(report,f,indent=2)
print('RADIO_SOURCE_ROUNDTRIP_OK',json.dumps(report))
