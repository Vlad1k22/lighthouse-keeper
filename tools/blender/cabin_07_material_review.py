import bpy, json
project=r'C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper'
# A portable continuation after reopening the saved .blend; no dependency on the ship scene.
palette={'KC_OldIvoryTrim':'b4aa8f','KC_BareTimber':'72624d','KC_WetStone':'555955',
         'KC_DarkIron':'2a3030','KC_DullZinc':'737d77','KC_Brass':'8e7952',
         'KC_WindowWarm':'bb8748','KC_Cavity':'202723','KC_LanternGlass':'d4a465','KC_Cloth':'55584b'}
for name,value in palette.items():
    mat=bpy.data.materials[name]
    srgb=[int(value[i:i+2],16)/255 for i in (0,2,4)]
    linear=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in srgb]
    mat.diffuse_color=(*linear,1)
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=mat.diffuse_color
    if bs.inputs['Emission Strength'].default_value>0:bs.inputs['Emission Color'].default_value=mat.diffuse_color
    mat['palette_color_space']='sRGB palette converted to scene-linear before glTF export'
EX=bpy.data.collections['KC_GAME_EXPORT'];EX.hide_viewport=False;EX.hide_render=False
bpy.ops.object.select_all(action='DESELECT')
for obj in EX.objects:obj.hide_set(False);obj.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['KC_Visual']
bpy.ops.export_scene.gltf(filepath=project+'/assets/models/keeper_cabin/keeper_cabin_v01.glb',export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,
    export_extras=True,export_materials='EXPORT',export_texcoords=True,export_normals=True,export_tangents=True)
EX.hide_viewport=True;EX.hide_render=True
bpy.ops.object.select_all(action='DESELECT');root=bpy.data.objects['KC_KeeperCabin'];root.select_set(True);bpy.context.view_layer.objects.active=root
bpy.ops.wm.save_as_mainfile(filepath=project+'/assets/source_blender/keeper_cabin/A04_keeper_cabin_v01.blend',compress=True)
bpy.context.scene.render.filepath=project+'/docs/art/keeper_cabin/blender-beauty.png'
bpy.ops.render.render(write_still=True)
print('CABIN_PALETTE_REVIEW_OK: scene-linear PBR values, source and GLB updated')
