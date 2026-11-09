"""Run in Blender via MCP. Dovetails the supplied tower with the Godot beacon."""
import bpy
import bmesh
import math
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

PROJECT = Path(r"C:/Users/Redmi/Documents/Codex/2026-09-28/x20/outputs/lighthouse-keeper")
SOURCE = Path(r"C:/Users/Redmi/Downloads/Telegram Desktop/маяк.blend")
AUTHOR = PROJECT / "assets/source_blender/lighthouse"
EXPORT = PROJECT / "assets/models/lighthouse"
ART = PROJECT / "docs/art/lighthouse"
for folder in (AUTHOR, EXPORT, ART):
    folder.mkdir(parents=True, exist_ok=True)

scene = bpy.context.scene
for o in list(scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)

def collection(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c

author = collection("LH_EDITABLE")
game = collection("LH_GAME_EXPORT")
studio = collection("LH_STUDIO_NOT_EXPORTED")
groups = {}

def put(obj, c):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    c.objects.link(obj)

def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4

def material(name, hexcolor, roughness, metal=0, alpha=1, emission=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    rgb = tuple(linear(int(hexcolor[i:i+2], 16) / 255) for i in (0, 2, 4))
    m.diffuse_color = (*rgb, alpha)
    bs = m.node_tree.nodes.get("Principled BSDF")
    for key, value in {"Base Color": (*rgb, 1), "Roughness": roughness, "Metallic": metal, "Alpha": alpha}.items():
        bs.inputs[key].default_value = value
    if alpha < 1:
        m.surface_render_method = 'BLENDED'
    if emission:
        bs.inputs["Emission Color"].default_value = (*rgb, 1)
        bs.inputs["Emission Strength"].default_value = emission
    return m

def noise(x, y, nx, ny, seed):
    grid = np.random.default_rng(seed).random((ny, nx), dtype=np.float32)
    xx, yy = x*nx, y*ny
    ix, iy = np.floor(xx).astype(int), np.floor(yy).astype(int)
    fx, fy = xx-ix, yy-iy
    fx, fy = fx*fx*(3-2*fx), fy*fy*(3-2*fy)
    a = grid[iy % ny, ix % nx]*(1-fx)+grid[iy % ny, (ix+1) % nx]*fx
    b = grid[(iy+1) % ny, ix % nx]*(1-fx)+grid[(iy+1) % ny, (ix+1) % nx]*fx
    return (a*(1-fy)+b*fy).astype(np.float32)

def image_map(label, array, noncolor=False):
    h,w = array.shape[:2]
    rgb = array if array.ndim==3 else np.broadcast_to(array[:,:,None], (h,w,3))
    rgba = np.ones((h,w,4), np.float32)
    rgba[:,:,:3] = np.clip(rgb, 0, 1)
    im = bpy.data.images.new(label,width=w,height=h,alpha=False)
    im.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = str(AUTHOR / (label+".png"))
    im.file_format = 'PNG'
    im.save()
    im.pack()
    return im

def textured(m, label, colors, roughness, height, bump):
    nt = m.node_tree
    bs = nt.nodes.get("Principled BSDF")
    dx = (np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*bump
    dy = (np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*bump
    norm = np.sqrt(dx*dx+dy*dy+1)
    normal = np.stack((.5-dx/norm*.5,.5-dy/norm*.5,.5+.5/norm),axis=2)
    for suffix, values, dest in (("Color",colors,"Base Color"),("Rough",roughness,"Roughness"),("Normal",normal,"Normal")):
        node=nt.nodes.new('ShaderNodeTexImage')
        node.label=label+" "+suffix
        node.image=image_map(label+"_"+suffix,values,suffix!="Color")
        if dest=="Normal":
            n=nt.nodes.new('ShaderNodeNormalMap')
            n.inputs['Strength'].default_value=.8
            nt.links.new(node.outputs['Color'],n.inputs['Color'])
            nt.links.new(n.outputs['Normal'],bs.inputs[dest])
        else:
            nt.links.new(node.outputs['Color'],bs.inputs[dest])

stone = material("LH Painted stone","b7ad96",.83)
w,h=1024,2048
y,x=np.mgrid[0:h,0:w].astype(np.float32)
x/=w; y/=h
slow=noise(x,y,11,17,21)
medium=noise(x,y,57,81,22)
fine=noise(x,y,231,367,23)
drips=noise(x,y,92,13,24)
row_coord=y*29+(medium-.5)*.057
row=np.floor(row_coord).astype(int)
col_coord=x*14+(row%2)*.5+(medium-.5)*.066
col=np.floor(col_coord).astype(int)
v=row_coord-row; u=col_coord-col
joint=np.clip(np.minimum(np.minimum(v,1-v)*1.25,np.minimum(u,1-u))*52,0,1)
tile=np.random.default_rng(25).uniform(.87,1.07,(31,14))[row%31,col%14]
fade=np.clip((slow-.38)*.9 + medium*.12 + (drips-.45)*.18,0,.58)
red=((y+medium*.008>.357)&(y+medium*.008<.579))
lower=np.clip((.26-y)*2.1,0,.48)
cream=np.array([.65,.63,.56],np.float32)
iron_oxide=np.array([.45,.231,.182],np.float32)
raw_stone=np.array([.37,.394,.372],np.float32)
paint=np.where(red[:,:,None],iron_oxide,cream)
weather=np.clip(fade+lower,0,.78)
colormap=(paint*(1-weather[:,:,None])+raw_stone*weather[:,:,None])*tile[:,:,None]
colormap*= (.89+.17*slow+.11*medium+.065*fine)[:,:,None]
colormap=colormap*(.53+.47*joint[:,:,None])
textured(stone,"LH_Tower",colormap,.68+.24*medium,joint*.30+medium*.24+fine*.11,5.5)

w=h=512
y,x=np.mgrid[0:h,0:w].astype(np.float32)
x/=w; y/=h
rough=noise(x,y,22,29,34)
blotches=noise(x,y,9,13,35)
grain=noise(x,y,94,123,36)
copper=material("LH Weathered copper","62604c",.65,.58)
patina=np.clip((blotches+rough*.6-.67)*2.4,0,1)
cc=np.array([.31,.251,.185])*(1-patina[:,:,None])+np.array([.24,.36,.327])*patina[:,:,None]
textured(copper,"LH_Copper",cc*(.82+.29*rough[:,:,None]),.46+.35*patina,rough*.28+grain*.15,4)
wood=material("LH Salt worn oak","654f3e",.88)
fibres=noise(x,y,125,12,38); broad=noise(x,y,16,4,39)
textured(wood,"LH_Oak",np.array([.31,.233,.172])*(.63+.45*fibres[:,:,None]+.35*broad[:,:,None]),.78+.19*fibres,fibres*.36+grain*.11,4)
iron=material("LH Charcoal iron","3c4541",.71,.55)
brass=material("LH Dull brass","8e7651",.56,.67)
base_mat=material("LH Granite plinth","585d55",.91)
shadow=material("LH Door and window recess","282722",.91)
window=material("LH Old window","715f46",.39,.15)
glass=material("LH Lantern glazing","8c9690",.3,.06,.28)
lens=material("LH Fresnel lens","eec282",.24,.1,1,1.8)

def classify(o, group, mat):
    o.data.materials.clear()
    o.data.materials.append(mat)
    for face in o.data.polygons:
        face.material_index=0
    groups.setdefault(group,[]).append(o)

def cylindrical_uv(o, total_h):
    mesh=o.data
    uv=mesh.uv_layers.active or mesh.uv_layers.new(name="Masonry")
    for poly in mesh.polygons:
        xyz=[mesh.vertices[mesh.loops[i].vertex_index].co for i in poly.loop_indices]
        angles=[(math.atan2(v.y,v.x)/(2*math.pi)+.75)%1 for v in xyz]
        if max(angles)-min(angles)>.5 and abs(poly.normal.z)<.9:
            angles=[a+1 if a<.5 else a for a in angles]
        for i,a,v in zip(poly.loop_indices,angles,xyz):
            uv.data[i].uv=(a,v.z/total_h) if abs(poly.normal.z)<.9 else (v.x*.24+.5,v.y*.24+.5)
        poly.use_smooth=abs(poly.normal.z)<.9

with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
    dst.objects=list(src.objects)
for o in dst.objects:
    if o is None or o.type!='MESH':
        continue
    name=o.name
    if name.startswith(("Береговая скала","Кладка — неровный шов")) or max(o.dimensions)>30:
        continue
    author.objects.link(o)
    bpy.context.view_layer.update()
    xy=.895 if name.startswith("Каменный цоколь") else .69
    mat=Matrix.Diagonal((xy,xy,.943,1.0)) @ o.matrix_world
    o.data=o.data.copy()
    o.data.transform(mat)
    o.parent=None
    o.matrix_world=Matrix.Identity(4)
    if name.startswith("МАЯК"):
        classify(o,"LH_Tower",stone)
        cylindrical_uv(o,9.43)
    elif name.startswith("Каменный"):
        classify(o,"LH_Base",base_mat)
    elif name.startswith("Купол — старая"):
        classify(o,"LH_Roof",copper)
        for face in o.data.polygons:face.use_smooth=True
    elif "дымчатое стекло" in name:
        # Remove cylinder caps so the warm optic is visible through the panes.
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.normal.z)>.85],context='FACES_ONLY')
        bm.to_mesh(o.data);bm.free()
        classify(o,"LH_Glass",glass)
    elif name.startswith(("Вход","Дверь","Окно")):
        m=window if "янтарное" in name else shadow if ("ниша" in name or "проём" in name) else wood if name.startswith(("Вход","Дверь")) and "ручка" not in name else iron
        classify(o,"LH_Entry",m)
    else:
        classify(o,"LH_Trim",iron)

def mesh_obj(name, group, mat):
    o=bpy.context.object;o.name=name
    put(o,author);classify(o,group,mat)
    return o

def cyl(name,at,r,depth,mat,group,vertices=32,top=None):
    if top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=at)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=top,depth=depth,location=at)
    o=mesh_obj(name,group,mat)
    for f in o.data.polygons:f.use_smooth=abs(f.normal.z)<.85
    return o

def bar(name,a,b,r,mat,group):
    a,b=Vector(a),Vector(b)
    o=cyl(name,(a+b)/2,r,(b-a).length,mat,group,12)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def ring(name,z,r,t,mat,group):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,major_radius=r,minor_radius=t,location=(0,0,z))
    o=mesh_obj(name,group,mat)
    for f in o.data.polygons:f.use_smooth=True
    return o

def box(name,at,dims,mat,group):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    o=mesh_obj(name,group,mat)
    o.dimensions=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return o

# Keep the supplied windows, door and dome; detail their surroundings.
for i in range(16):
    a=math.tau*i/16
    x,y=1.12*math.cos(a),1.12*math.sin(a)
    bar("Gallery stanchion",(x,y,9.55),(x,y,10.16),.024,iron,"LH_Trim")
for z in (9.80,10.16):
    ring("Gallery rail",z,1.12,.026,iron,"LH_Trim")
for z,r in ((.39,1.48),(9.31,1.06),(9.56,1.18),(11.19,.775)):
    ring("Structural collar",z,r,.038,iron,"LH_Trim")
for i in range(8):
    a=math.tau*i/8
    bar("Lightning finial brace",(.12*math.cos(a),.12*math.sin(a),12.48),(.02*math.cos(a),.02*math.sin(a),12.86),.014,brass,"LH_Roof")
for xx in (-.246,.246):
    box("Entry jamb",(xx,-1.57,1.065),(.08,.105,1.46),iron,"LH_Entry")
box("Door lintel",(0,-1.57,1.81),(.58,.105,.08),iron,"LH_Entry")
box("Threshold",(0,-1.57,.33),(.65,.26,.105),base_mat,"LH_Base")
for z in (.68,1.51):
    box("Iron strap hinge",(0,-1.604,z),(.37,.022,.043),iron,"LH_Entry")
bar("Service conduit",(.72,-1.29,.39),(.68,-1.21,1.59),.022,iron,"LH_Entry")
box("Service junction box",(.69,-1.26,1.21),(.19,.12,.24),iron,"LH_Entry")

# Fresnel stack centred exactly on Godot's existing 10.65 m beam.
cyl("Optic pedestal",(0,0,9.96),.23,.6,iron,"LH_Trim")
cyl("Optic base",(0,0,10.24),.35,.09,brass,"LH_Trim")
cyl("Optic crown",(0,0,11.06),.31,.075,brass,"LH_Trim")
for i in range(13):
    dz=(i-6)*.061
    r=.34-.13*(abs(i-6)/6)**1.45
    cyl("Fresnel prism %02d"%i,(0,0,10.65+dz),r,.059,lens,"LH_Lens",48,max(.12,r-.025))
for i in range(4):
    a=math.tau*i/4+.5
    x,y=.375*math.cos(a),.375*math.sin(a)
    bar("Optic support",(x,y,10.23),(x,y,11.05),.018,brass,"LH_Trim")

# Merge only export copies, leaving the source parts editable.
joined=[]
for name,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for orig in parts:
        o=orig.copy();o.data=orig.data.copy();game.objects.link(o)
        o.select_set(True);copies.append(o)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if len(copies)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=name;o.data.name=name
    bm=bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bm.to_mesh(o.data)
    bm.free()
    joined.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in joined:o.select_set(True)
bpy.context.view_layer.objects.active=joined[0]
bpy.ops.export_scene.gltf(filepath=str(EXPORT/"lighthouse_v01.glb"),export_format='GLB',
    use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,
    export_tangents=True,export_cameras=False,export_lights=False,export_animations=False)
for o in joined:o.select_set(False)
game.hide_render=True
game.hide_viewport=True

def look_at(obj,at):
    obj.rotation_euler=(Vector(at)-obj.location).to_track_quat('-Z','Y').to_euler()

floor=material("Studio ground","384041",.96)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035))
o=bpy.context.object;o.name="Studio ground";put(o,studio);o.data.materials.append(floor)
bpy.ops.object.camera_add(location=(12,-21,14.0))
cam=bpy.context.object;put(cam,studio);look_at(cam,(0,0,6.35))
cam.data.type='ORTHO';cam.data.ortho_scale=14.8;scene.camera=cam
for name,at,energy,size,color in (("Overcast key",(-7,-10,17),2050,10,(.81,.89,1)),("Warm edge",(6,5,13),1550,8,(1,.82,.60)),("Front fill",(4,-9,7),650,7,(.78,.88,1))):
    bpy.ops.object.light_add(type='AREA',location=at)
    o=bpy.context.object;o.name=name;put(o,studio);look_at(o,(0,0,6))
    o.data.energy=energy;o.data.size=size;o.data.color=color
scene.world=bpy.data.worlds.new('LH Overcast');scene.world.use_nodes=True
bg=scene.world.node_tree.nodes.get("Background")
bg.inputs[0].default_value=(.24,.30,.34,1)
bg.inputs[1].default_value=.60
scene.render.engine='BLENDER_EEVEE'
scene.eevee.taa_render_samples=32
scene.render.resolution_x=820;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.filepath=str(ART/"blender-beauty.png")
bpy.ops.render.render(write_still=True)
studio.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
for o in author.objects:
    if o.name.startswith("МАЯК"):
        o.select_set(True);bpy.context.view_layer.objects.active=o;break
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.region_3d.view_location=(0,0,6.35)
            space.region_3d.view_distance=17
            space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            space.region_3d.view_perspective='ORTHO'
            space.shading.color_type='MATERIAL'
scene.render.filepath="//lighthouse-render.png"
bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/"lighthouse_v01.blend"))
print("LIGHTHOUSE_EXPORTED",len(author.objects),len(joined),[o.name for o in joined])
