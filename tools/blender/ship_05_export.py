import bpy
globals().update(bpy.app.driver_namespace["SV_BUILD"])
import bmesh
EX=bpy.data.collections.new("SV_GAME_EXPORT")
for obj in COL.objects: obj.hide_set(False)
bpy.context.scene.collection.children.link(EX)
eroot=bpy.data.objects.new("SV_Visual",None)
EX.objects.link(eroot)
eroot["asset_id"]="A37_coastal_vessel_v01"
eroot["authoring"]="Blender 5.2.2 LTS via MCP for Blender 2.2.4"
eroot["units"]="metres"
eroot["deck_height"]=1.0
eroot["gameplay"]="visual replacement; existing Godot physics and interactions retained"
dg=bpy.context.evaluated_depsgraph_get()
groups={}
for obj in list(COL.objects):
    if obj.type not in {"MESH","FONT","CURVE"}:continue
    data=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    if not data or not data.vertices:continue
    data.validate(clean_customdata=False)
    copy=bpy.data.objects.new(obj.name+"_export",data)
    EX.objects.link(copy)
    copy.matrix_world=obj.matrix_world.copy()
    copy.parent=eroot
    group=obj.get("assembly","Equipment")
    groups.setdefault(group,[]).append(copy)
names={"Hull":"SV_Hull","Deck":"SV_Deck","Wheelhouse":"SV_Wheelhouse","Equipment":"SV_Equipment","Rails":"SV_Rails","Rigging":"SV_Rigging","Gangplank":"SV_Gangplank","StageHullDamage":"SV_HullDamage","StageHullRepaired":"SV_HullPatch_Repaired","StageEngineReady":"SV_EngineReady"}
for group,objects in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=names[group]
    # Triangulation is performed inside Blender before glTF export.
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    obj["source_assembly"]=group
    # Keep a stable, shared origin for every repair state and assembly.
    world=obj.matrix_world.copy()
    obj.data.transform(world)
    obj.matrix_world.identity()
    obj.parent=eroot
    obj.data.update()
bpy.ops.object.select_all(action="DESELECT")
for obj in EX.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=eroot
properties=bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
opts={"filepath":EXPORT+"/coastal_vessel_v01.glb","export_format":"GLB","use_selection":True,"export_yup":True,"export_apply":True,"export_animations":False,"export_cameras":False,"export_lights":False,"export_extras":True,"export_materials":"EXPORT","export_texcoords":True,"export_normals":True,"export_tangents":True,"export_image_format":"AUTO"}
bpy.ops.export_scene.gltf(**{k:v for k,v in opts.items() if k in properties})
total_triangles=sum(len(obj.data.polygons) for obj in EX.objects if obj.type=="MESH")
total_vertices=sum(len(obj.data.vertices) for obj in EX.objects if obj.type=="MESH")
stats={"asset":"A37-A44 / Coastal vessel Северный","blender":bpy.app.version_string,"pipeline":"MCP stdio → mcp-for-blender 2.2.4 → Blender addon","source_objects":len(COL.objects),"export_meshes":len([o for o in EX.objects if o.type=="MESH"]),"triangles":total_triangles,"vertices":total_vertices,"materials":sorted(M.keys()),"glb":EXPORT+"/coastal_vessel_v01.glb","deck_height_m":1.0,"axis":"Blender Z-up,+Y bow → Godot Y-up,-Z bow"}
with open(PREVIEW+"/asset-statistics.json","w",encoding="utf-8") as f:json.dump(stats,f,ensure_ascii=False,indent=2)
EX.hide_viewport=True
EX.hide_render=True
bpy.ops.object.select_all(action="DESELECT")
ROOT.select_set(True)
bpy.context.view_layer.objects.active=ROOT
# Save a fully editable source with all images packed and without an external dependency.
for img in bpy.data.images:
    if img.name!="Render Result" and img.source=="FILE":
        try:img.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+"/A37_coastal_vessel_v01.blend",compress=True)
bpy.app.driver_namespace["SV_BUILD"].update(globals())
print("EXPORT_OK",json.dumps(stats,ensure_ascii=False))
