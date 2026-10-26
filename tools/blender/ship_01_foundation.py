"""Run through MCP execute_blender_code in Blender 5.2; not a Godot mesh generator."""
import bpy, math, random, os, json, numpy as np
from mathutils import Vector
PROJECT = r"C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper"
SOURCE = PROJECT+"/assets/source_blender/coastal_vessel"
EXPORT = PROJECT+"/assets/models/coastal_vessel"
PREVIEW = PROJECT+"/docs/art/coastal_vessel"
for path in [SOURCE,EXPORT,PREVIEW]: os.makedirs(path,exist_ok=True)
# A new dedicated factory-startup scene was opened for this asset.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name=="Collection": bpy.data.collections.remove(collection)
COL = bpy.data.collections.new("SV_SOURCE_EDITABLE")
bpy.context.scene.collection.children.link(COL)
ROOT = bpy.data.objects.new("SV_CoastalVessel",None)
COL.objects.link(ROOT)
ROOT["asset"]="A37-A44 / Северный"
ROOT["created_via"]="Blender 5.2.2 / MCP for Blender 2.2.4"
ROOT["forward"]="Blender +Y; glTF/Godot -Z"
ROOT["deck_height_m"]=1.0
ROOT["reference_length_m"]=17.8
M={}
rng=random.Random(407)
def srgb(hexvalue):
    return tuple(int(hexvalue[i:i+2],16)/255 for i in (0,2,4))
def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)
def noise(n,c,seed):
    r=np.random.default_rng(seed)
    grid=r.random((c+1,c+1),dtype=np.float32)
    p=np.linspace(0,c-.001,n,dtype=np.float32)
    idx=p.astype(np.int32); t=p-idx; t=t*t*(3-2*t)
    bottom=grid[idx[:,None],idx[None,:]]*(1-t[None,:])+grid[idx[:,None],idx[None,:]+1]*t[None,:]
    upper=grid[idx[:,None]+1,idx[None,:]]*(1-t[None,:])+grid[idx[:,None]+1,idx[None,:]+1]*t[None,:]
    return (bottom*(1-t[:,None])+upper*t[:,None]).astype(np.float32)
def image(name,channels,noncolor=False):
    n=channels.shape[0]
    rgba=np.ones((n,n,4),dtype=np.float32)
    if channels.ndim==2: rgba[:,:,:3]=channels[:,:,None]
    else: rgba[:,:,:3]=channels
    img=bpy.data.images.new(name,width=n,height=n,alpha=False)
    img.colorspace_settings.name="Non-Color" if noncolor else "sRGB"
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw=EXPORT+"/"+name+".png"
    img.file_format="PNG"
    img.save()
    img.pack()
    return img
def pbr(name,color,rough=.6,metallic=0):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.diffuse_color=(*srgb(color),1)
    mat.use_backface_culling=True
    bs=mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value=(*srgb(color),1)
    bs.inputs["Roughness"].default_value=rough
    bs.inputs["Metallic"].default_value=metallic
    M[name]=mat
    return mat
def texture_material(name,color,n,kind,seed):
    mat=pbr(name,color,.7,.35 if kind=="paint" else 0)
    a=noise(n,13,seed); b=noise(n,85,seed+1); c=noise(n,400,seed+2)
    base=np.array(srgb(color),dtype=np.float32)
    if kind=="wood":
        yy,xx=np.mgrid[0:n,0:n].astype(np.float32)/n
        grain=np.sin(xx*360+np.sin(yy*8)*2+b*5)*.5+.5
        hair=np.power(np.maximum(0,np.sin(xx*1900+a*4)),18)
        tint=.72+a*.30+grain*.12+c*.05-hair*.06
        colors=np.clip(base[None,None,:]*tint[:,:,None],0,1)
        for k in range(5):
            cx=.1+k*.19;cy=.15+(k*.213)%0.7
            d=np.sqrt(((xx-cx)*3)**2+((yy-cy)*.7)**2)
            knot=np.exp(-d*35)*(.6+.4*np.sin(d*250))
            colors*=1-knot[:,:,None]*.32
        rough=np.clip(.77+(a-.5)*.16,0,1)
        height=(grain*.13+b*.05+c*.018)
    else:
        mask=smooth(.54,.73,a*.65+b*.28+c*.07)
        edge=smooth(.49,.57,a*.65+b*.28+c*.07)*(1-mask)
        rust=np.stack([.26+b*.15,.105+b*.08,.05+b*.035],axis=-1)
        colors=base[None,None,:]*(.86+c[:,:,None]*.12+a[:,:,None]*.14)
        colors=colors*(1-mask[:,:,None])+rust*mask[:,:,None]
        colors*=1-edge[:,:,None]*.09
        # Fine, sparse surface scratches, rather than a repeating crack shader.
        yy,xx=np.mgrid[0:n,0:n].astype(np.float32)/n
        scratch=np.power(np.maximum(0,np.sin(xx*800+b*3)),70)*smooth(.7,.9,c)*.12
        colors=np.clip(colors+scratch[:,:,None],0,1)
        rough=np.clip(.58+mask*.27+(c-.5)*.07,0,1)
        height=mask*.15+b*.025+c*.008
    dx,dy=np.gradient(height)
    normals=np.stack([-dy*24,-dx*24,np.ones_like(dx)],axis=-1)
    normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
    normal_img=image(name+"_Normal",normals*.5+.5,True)
    albedo_img=image(name+"_BaseColor",colors)
    # glTF metallic-roughness: roughness in G, metalness in B.
    orm=np.zeros((n,n,3),dtype=np.float32)
    orm[:,:,0]=1
    orm[:,:,1]=rough
    orm[:,:,2]=.28 if kind=="paint" else 0
    orm_img=image(name+"_ORM",orm,True)
    nt=mat.node_tree;bs=nt.nodes.get("Principled BSDF")
    tx=nt.nodes.new("ShaderNodeTexImage");tx.image=albedo_img
    nt.links.new(tx.outputs["Color"],bs.inputs["Base Color"])
    txr=nt.nodes.new("ShaderNodeTexImage");txr.image=orm_img
    sep=nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(txr.outputs["Color"],sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"],bs.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"],bs.inputs["Metallic"])
    txn=nt.nodes.new("ShaderNodeTexImage");txn.image=normal_img
    normal=nt.nodes.new("ShaderNodeNormalMap");normal.inputs["Strength"].default_value=.4
    nt.links.new(txn.outputs["Color"],normal.inputs["Color"])
    nt.links.new(normal.outputs["Normal"],bs.inputs["Normal"])
    return mat
texture_material("SV_BluePaint","526769",4096,"paint",41)
texture_material("SV_IvoryPaint","b2ad91",2048,"paint",82)
texture_material("SV_WeatheredDeck","887158",2048,"wood",125)
texture_material("SV_Antifouling","653d34",1024,"paint",251)
pbr("SV_DarkIron","303b3b",.68,.75)
pbr("SV_Galvanized","88918b",.4,.8)
pbr("SV_Brass","977e4b",.4,.65)
pbr("SV_Rubber","202624",.94,0)
pbr("SV_Rope","8f866e",.96,0)
pbr("SV_Orange","bd6639",.65,0)
pbr("SV_Lettering","d8d0ad",.73,0)
pbr("SV_Glass","34494b",.18,.25)
M["SV_Glass"].node_tree.nodes.get("Principled BSDF").inputs["Coat Weight"].default_value=.65
pbr("SV_Interior","424a40",.85,0)
pbr("SV_RedLamp","9c3530",.2,.05)
pbr("SV_GreenLamp","427c60",.2,.05)
for name in ["SV_RedLamp","SV_GreenLamp"]:
    bs=M[name].node_tree.nodes.get("Principled BSDF")
    bs.inputs["Emission Color"].default_value=M[name].diffuse_color
    bs.inputs["Emission Strength"].default_value=.5
def attach(obj,name,mat,group="Equipment"):
    obj.name=name
    for col in list(obj.users_collection): col.objects.unlink(obj)
    COL.objects.link(obj)
    obj.parent=ROOT
    obj["assembly"]=group
    if mat: obj.data.materials.append(M[mat] if isinstance(mat,str) else mat)
    return obj
def bevel(obj,width=.025,segments=3):
    mod=obj.modifiers.new("Manufactured edge radius","BEVEL")
    mod.width=width;mod.segments=segments
    mod.affect="EDGES"
    return obj
def box(name,at,size,mat,bevel_size=.02,group="Equipment"):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    obj=attach(bpy.context.object,name,mat,group)
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel_size: bevel(obj,bevel_size)
    return obj
def mesh(name,verts,faces,mat,group="Hull",uv=None):
    data=bpy.data.meshes.new(name+"_mesh")
    data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);COL.objects.link(obj);obj.parent=ROOT
    obj["assembly"]=group
    data.materials.append(M[mat])
    layer=data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        for li in poly.loop_indices:
            co=data.vertices[data.loops[li].vertex_index].co
            layer.data[li].uv=uv(co) if uv else (co.x*.5,co.y*.5)
    return obj
def cylinder(name,a,b,radius,mat,vertices=16,group="Equipment"):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=(b-a).length,location=(a+b)/2)
    obj=attach(bpy.context.object,name,mat,group)
    obj.rotation_euler=(b-a).to_track_quat("Z","Y").to_euler()
    bevel(obj,min(radius*.13,.018),2)
    for p in obj.data.polygons:p.use_smooth=len(p.vertices)==4
    return obj
def tube(name,points,radius,mat,sides=8,group="Rails"):
    verts=[];faces=[]
    for i,point in enumerate(points):
        tangent=Vector(points[min(len(points)-1,i+1)])-Vector(points[max(0,i-1)])
        tangent.normalize()
        side=tangent.cross(Vector((0,0,1)))
        if side.length<.01:side=tangent.cross(Vector((0,1,0)))
        side.normalize();up=tangent.cross(side).normalized()
        for j in range(sides):
            v=Vector(point)+radius*(side*math.cos(j*math.tau/sides)+up*math.sin(j*math.tau/sides))
            verts.append(tuple(v))
        if i:
            for j in range(sides):
                a=(i-1)*sides+j;b=(i-1)*sides+(j+1)%sides
                faces.append((a,b,i*sides+(j+1)%sides,i*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    obj=mesh(name,verts,faces,mat,group)
    for p in obj.data.polygons:p.use_smooth=True
    return obj
def torus(name,at,major,minor,mat,rotation=(0,0,0),group="Equipment"):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=32,minor_segments=10,location=at,rotation=rotation)
    obj=attach(bpy.context.object,name,mat,group)
    for p in obj.data.polygons:p.use_smooth=True
    return obj
def bolt(name,at,r=.025,group="Equipment"):
    return cylinder(name,(at[0],at[1],at[2]-.012),(at[0],at[1],at[2]+.012),r,"SV_Galvanized",6,group)
bpy.context.scene.unit_settings.system="METRIC"
bpy.context.scene.unit_settings.scale_length=1
bpy.context.scene.render.engine="CYCLES"
bpy.context.scene.cycles.samples=64
bpy.context.scene.cycles.use_denoising=True
bpy.context.scene.world.color=(.18,.21,.24)
bpy.context.scene.view_settings.view_transform="AgX"
bpy.app.driver_namespace["SV_BUILD"]=globals().copy()
print("FOUNDATION_OK",len(M),"materials",len(bpy.data.images),"images; MCP modeling initialized")
