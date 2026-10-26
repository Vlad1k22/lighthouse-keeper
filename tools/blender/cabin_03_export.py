import bpy, bmesh
globals().update(bpy.app.driver_namespace['KC_BUILD'])
# Repeatable export after a source refinement: remove only this asset's previous export copies.
old=bpy.data.collections.get('KC_GAME_EXPORT')
if old:
    for obj in list(old.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(old)
EX=bpy.data.collections.new('KC_GAME_EXPORT');bpy.context.scene.collection.children.link(EX)
eroot=bpy.data.objects.new('KC_Visual',None);EX.objects.link(eroot)
eroot['asset_id']='A04_keeper_cabin_v01'
eroot['pipeline']='Blender MCP; all geometry and UVs authored in Blender'
eroot['units']='metres; front +Z in Godot'
eroot['collision']='Existing Godot primitives; no dense trimesh collision'
eroot['door_hinge_godot']='(-0.49, 0, 2.23)'
dg=bpy.context.evaluated_depsgraph_get();groups={}
for obj in list(COL.objects):
    if obj.type!='MESH':continue
    data=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    if not data or not data.vertices:continue
    data.validate(clean_customdata=False)
    copy=bpy.data.objects.new(obj.name+'_export',data);EX.objects.link(copy)
    copy.matrix_world=obj.matrix_world.copy()
    groups.setdefault(obj.get('assembly','Details'),[]).append(copy)
for group,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object
    obj.name='KC_'+group
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    obj.data.transform(obj.matrix_world.copy());obj.matrix_world.identity();obj.parent=eroot
    if group=='Door':
        # Store a true hinge origin for future animation, while maintaining the closed pose.
        hinge=Vector((-.49,-2.23,0))
        for vertex in obj.data.vertices:vertex.co-=hinge
        obj.location=hinge
    obj.data.update();obj['source_assembly']=group
    if not obj.data.uv_layers:uv_project(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in EX.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=eroot
bpy.ops.export_scene.gltf(filepath=EXPORT+'/keeper_cabin_v01.glb',export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,
    export_extras=True,export_materials='EXPORT',export_texcoords=True,export_normals=True,export_tangents=True)
stats={'asset':'A04 / Keeper cabin','pipeline':'MCP stdio -> mcp-for-blender 2.2.4 -> Blender addon',
       'blender':bpy.app.version_string,'source_objects':len(COL.objects),
       'export_meshes':len([o for o in EX.objects if o.type=='MESH']),
       'triangles':sum(len(o.data.polygons) for o in EX.objects if o.type=='MESH'),
       'vertices':sum(len(o.data.vertices) for o in EX.objects if o.type=='MESH'),
       'surfaces':sum(len(o.data.materials) for o in EX.objects if o.type=='MESH'),
       'materials':sorted(M.keys()),'texture_sizes':{img.name:list(img.size) for img in bpy.data.images if img.packed_file},
       'budget':'Shared 1024px wood and roof, 512px chimney; constant materials for hidden/simple surfaces',
       'closed_shell':True,'gameplay':'Existing exterior sleep, cook, workbench and radio retained',
       'source':SOURCE+'/A04_keeper_cabin_v01.blend','glb':EXPORT+'/keeper_cabin_v01.glb'}
with open(PREVIEW+'/asset-statistics.json','w',encoding='utf-8') as f:json.dump(stats,f,ensure_ascii=False,indent=2)
EX.hide_viewport=True;EX.hide_render=True
bpy.ops.object.select_all(action='DESELECT');ROOT.select_set(True);bpy.context.view_layer.objects.active=ROOT
for img in bpy.data.images:
    if img.name!='Render Result':
        try:img.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+'/A04_keeper_cabin_v01.blend',compress=True)
bpy.app.driver_namespace['KC_BUILD'].update(globals())
print('CABIN_EXPORT_OK',json.dumps(stats,ensure_ascii=False))
