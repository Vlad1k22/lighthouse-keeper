import bpy, bmesh
globals().update(bpy.app.driver_namespace['RS_BUILD'])
old=bpy.data.collections.get('RS_GAME_EXPORT')
if old:
    for obj in list(old.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(old)
EX=bpy.data.collections.new('RS_GAME_EXPORT');bpy.context.scene.collection.children.link(EX)
eroot=bpy.data.objects.new('RS_Visual',None);EX.objects.link(eroot)
eroot['asset_id']='A26-A28_radio_station_v01';eroot['authoring']='Blender MCP'
eroot['units']='metres; front +Z in Godot'
eroot['repair_variants']='RS_PanelFault / RS_PanelOnline / RS_BatteryInstalled'
dg=bpy.context.evaluated_depsgraph_get();groups={}
for obj in list(COL.objects):
    if obj.type!='MESH':continue
    data=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    if not data or not data.vertices:continue
    data.validate(clean_customdata=False)
    copy=bpy.data.objects.new(obj.name+'_export',data);EX.objects.link(copy);copy.matrix_world=obj.matrix_world.copy()
    groups.setdefault(obj.get('assembly','Hut'),[]).append(copy)
for group,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='RS_'+group
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    obj.data.transform(obj.matrix_world.copy());obj.matrix_world.identity();obj.parent=eroot;obj.data.update()
    obj['source_assembly']=group
    if not obj.data.uv_layers:uv_project(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in EX.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=eroot
bpy.ops.export_scene.gltf(filepath=EXPORT+'/radio_station_v01.glb',export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,
    export_extras=True,export_materials='EXPORT',export_texcoords=True,export_normals=True,export_tangents=True)
stats={'asset':'A26-A28 / Radio station and antenna','pipeline':'MCP stdio -> mcp-for-blender 2.2.4 -> Blender addon',
       'blender':bpy.app.version_string,'source_objects':len(COL.objects),
       'export_meshes':len([obj for obj in EX.objects if obj.type=='MESH']),
       'triangles':sum(len(obj.data.polygons) for obj in EX.objects if obj.type=='MESH'),
       'vertices':sum(len(obj.data.vertices) for obj in EX.objects if obj.type=='MESH'),
       'surfaces':sum(len(obj.data.materials) for obj in EX.objects if obj.type=='MESH'),
       'materials':sorted(M.keys()),'texture_sizes':{img.name:list(img.size) for img in bpy.data.images if img.packed_file},
       'hut_footprint_m':[5,3.7],'mast_height_m':10.05,
       'budget':'Shared 1024px plaster and steel, 512px exposed brick; constant materials on simple parts',
       'origin_godot':[-12,1,-39.5],'forward':'Blender -Y -> Godot +Z',
       'closed_shell':True,'repair_variants':['RS_PanelFault','RS_PanelOnline','RS_BatteryInstalled']}
with open(PREVIEW+'/asset-statistics.json','w',encoding='utf-8') as f:json.dump(stats,f,ensure_ascii=False,indent=2)
EX.hide_viewport=True;EX.hide_render=True
for obj in COL.objects:
    if obj.get('assembly') in ('PanelOnline','BatteryInstalled'):
        obj.hide_set(True);obj.hide_render=True
bpy.ops.object.select_all(action='DESELECT');ROOT.select_set(True);bpy.context.view_layer.objects.active=ROOT
for img in bpy.data.images:
    if img.name!='Render Result':
        try:img.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+'/A26_radio_station_v01.blend',compress=True)
bpy.app.driver_namespace['RS_BUILD'].update(globals())
print('RADIO_EXPORT_OK',json.dumps(stats,ensure_ascii=False))
