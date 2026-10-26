"""A04 keeper cabin: execute inside Blender through MCP, in a dedicated new file."""
import bpy, math, random, json, os
import numpy as np
from mathutils import Vector

PROJECT = r"C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper"
SOURCE = PROJECT + '/assets/source_blender/keeper_cabin'
EXPORT = PROJECT + '/assets/models/keeper_cabin'
PREVIEW = PROJECT + '/docs/art/keeper_cabin'
for path in (SOURCE, EXPORT, PREVIEW): os.makedirs(path, exist_ok=True)
if bpy.data.filepath and 'keeper_cabin' not in bpy.data.filepath:
    raise RuntimeError('Use a dedicated new Blender file; do not overwrite another asset.')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name == 'Collection': bpy.data.collections.remove(collection)
COL = bpy.data.collections.new('KC_SOURCE_EDITABLE')
bpy.context.scene.collection.children.link(COL)
ROOT = bpy.data.objects.new('KC_KeeperCabin', None)
COL.objects.link(ROOT)
ROOT['asset_id'] = 'A04_keeper_cabin_v01'
ROOT['authoring'] = 'Blender 5.2.2 LTS via MCP for Blender 2.2.4'
ROOT['units'] = 'metres; Blender Z-up; front -Y becomes Godot +Z'
ROOT['scope'] = 'Exterior asset; no inaccessible detailed interior or underside textures'
ROOT['placement'] = 'Godot World/IslandGeometry/KeeperCabin at (5,1,0)'
M = {}
rng = random.Random(1404)

def rgb(value): return tuple(int(value[i:i+2],16)/255 for i in (0,2,4))

def noise(n, c, seed):
    r = np.random.default_rng(seed)
    grid = r.random((c+1,c+1), dtype=np.float32)
    p = np.linspace(0,c-.001,n,dtype=np.float32)
    j = p.astype(np.int32); f=p-j; f=f*f*(3-2*f)
    low=grid[j[:,None],j[None,:]]*(1-f[None,:])+grid[j[:,None],j[None,:]+1]*f[None,:]
    high=grid[j[:,None]+1,j[None,:]]*(1-f[None,:])+grid[j[:,None]+1,j[None,:]+1]*f[None,:]
    return low*(1-f[:,None])+high*f[:,None]

def ramp(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)

def material(name,color,rough=.8,metal=0,emission=0):
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    # Principled constants are scene-linear; hex palette values are sRGB.
    linear=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb(color))
    mat.diffuse_color=(*linear,1)
    mat.use_backface_culling=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=mat.diffuse_color
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=metal
    if emission:
        bs.inputs['Emission Color'].default_value=mat.diffuse_color
        bs.inputs['Emission Strength'].default_value=emission
    M[name]=mat
    return mat

def image(name,data,noncolor=False):
    n=data.shape[0]
    rgba=np.ones((n,n,4),dtype=np.float32)
    rgba[:,:,:3]=data if data.ndim==3 else data[:,:,None]
    img=bpy.data.images.new(name,width=n,height=n,alpha=False)
    img.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw=SOURCE+'/'+name+'.png'
    img.file_format='PNG';img.save();img.pack()
    return img

def textured(name,color,n,kind,seed):
    mat=material(name,color)
    a=noise(n,9,seed); b=noise(n,65,seed+1); c=noise(n,260,seed+2)
    yy,xx=np.mgrid[0:n,0:n].astype(np.float32)/n
    base=np.array(rgb(color),dtype=np.float32)
    if kind=='wood':
        grain=(np.sin(yy*530+np.sin(xx*9)*2+b*3)*.5+.5)
        fine=np.power(np.maximum(0,np.sin(yy*1800+a*3)),18)
        bare=ramp(.54,.77,a*.6+b*.3+c*.1)
        colors=base[None,None,:]*(.76+a[:,:,None]*.25+grain[:,:,None]*.15)
        raw=np.array(rgb('82745c'))[None,None,:]*(.75+b[:,:,None]*.25)
        colors=colors*(1-bare[:,:,None])+raw*bare[:,:,None]
        colors*=1-fine[:,:,None]*.14
        for k in range(4):
            d=np.sqrt(((xx-(.13+k*.23))*.55)**2+((yy-(.18+k*.19))*2.6)**2)
            knot=np.exp(-d*48)*(.5+.5*np.sin(d*520))
            colors*=1-knot[:,:,None]*.38
        height=grain*.06+b*.035+c*.006-fine*.025
        rough=np.clip(.78+bare*.12+c*.05,0,1); metallic=np.zeros_like(a)
    elif kind=='roof':
        rust=ramp(.55,.78,a*.6+b*.3+c*.1)
        fleck=ramp(.73,.91,c)*ramp(.48,.66,b)
        rust=np.clip(rust+fleck*.5,0,1)
        colors=base[None,None,:]*(.76+a[:,:,None]*.30+c[:,:,None]*.08)
        rust_color=np.stack([.24+b*.16,.102+b*.08,.046+b*.05],axis=-1)
        colors=colors*(1-rust[:,:,None])+rust_color*rust[:,:,None]
        height=rust*.11+b*.014+c*.004
        rough=.52+rust*.35;metallic=.63*(1-rust)
    else:
        # A small seamless brick atlas: visible chimney only, not hidden foundation faces.
        row=np.floor(yy*10); seamx=np.mod(xx*5+(np.mod(row,2))*.5,1)
        seamy=np.mod(yy*10,1)
        mortar=((seamx<.045)|(seamy<.075)).astype(np.float32)
        tint=.65+a*.35+b*.15
        colors=base[None,None,:]*tint[:,:,None]
        colors=colors*(1-mortar[:,:,None])+np.array(rgb('666259'))[None,None,:]*mortar[:,:,None]
        height=(1-mortar)*.13+b*.025;rough=.9+c*.05;metallic=np.zeros_like(a)
    gy,gx=np.gradient(height)
    normals=np.stack([-gx*32,-gy*32,np.ones_like(a)],axis=-1)
    normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
    albedo=image(name+'_BaseColor',np.clip(colors,0,1))
    normal=image(name+'_Normal',normals*.5+.5,True)
    orm=np.stack([np.ones_like(a),rough,metallic],axis=-1)
    packed=image(name+'_ORM',orm,True)
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
    tx=nt.nodes.new('ShaderNodeTexImage');tx.image=albedo
    nt.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    tx=nt.nodes.new('ShaderNodeTexImage');tx.image=packed
    sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tx.outputs['Color'],sep.inputs['Color'])
    nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    tx=nt.nodes.new('ShaderNodeTexImage');tx.image=normal
    normalnode=nt.nodes.new('ShaderNodeNormalMap');normalnode.inputs['Strength'].default_value=.45
    nt.links.new(tx.outputs['Color'],normalnode.inputs['Color']);nt.links.new(normalnode.outputs['Normal'],bs.inputs['Normal'])
    return mat

textured('KC_WeatheredPaint','51574c',1024,'wood',14)
textured('KC_StandingSeamSteel','444d4e',1024,'roof',114)
textured('KC_ChimneyBrick','735547',512,'brick',214)
material('KC_OldIvoryTrim','b4aa8f',.83)
material('KC_BareTimber','72624d',.9)
material('KC_WetStone','555955',.95)
material('KC_DarkIron','2a3030',.63,.7)
material('KC_DullZinc','737d77',.48,.75)
material('KC_Brass','8e7952',.5,.65)
material('KC_WindowGlass','33413d',.23,.1)
material('KC_WindowWarm','bb8748',.72,0,.45)
material('KC_Cavity','202723',.96)
material('KC_LanternGlass','d4a465',.25,0,1.5)
material('KC_Cloth','55584b',.98)

def attach(obj,name,mat,group):
    obj.name=name
    for col in list(obj.users_collection):col.objects.unlink(obj)
    COL.objects.link(obj);obj.parent=ROOT;obj['assembly']=group
    if mat:obj.data.materials.append(M[mat])
    return obj

def uv_project(obj,scale=0.5):
    layer=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
    offset=rng.random()*2
    for p in obj.data.polygons:
        normal=p.normal
        for li in p.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            if abs(normal.z)>.7:u,v=co.x,co.y
            elif abs(normal.y)>.7:u,v=co.x,co.z
            else:u,v=co.y,co.z
            layer.data[li].uv=(u*scale+offset,v*scale+offset*.7)

def bevel(obj,width=.015,segments=2):
    mod=obj.modifiers.new('Edge wear silhouette','BEVEL');mod.width=width;mod.segments=segments
    return obj

def box(name,at,size,mat,group='Structure',edge=.012):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    obj=attach(bpy.context.object,name,mat,group);obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    uv_project(obj)
    if edge:bevel(obj,edge)
    return obj

def mesh(name,verts,faces,mat,group='Structure'):
    data=bpy.data.meshes.new(name+'_Mesh');data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);COL.objects.link(obj);obj.parent=ROOT
    obj['assembly']=group;data.materials.append(M[mat]);uv_project(obj)
    return obj

def cylinder(name,a,b,r,mat,group='Details',sides=12):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=r,depth=(b-a).length,location=(a+b)/2)
    obj=attach(bpy.context.object,name,mat,group)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    bevel(obj,min(.008,r*.15),1)
    for p in obj.data.polygons:p.use_smooth=len(p.vertices)==4
    return obj

def beam(name,a,b,width,depth,mat,group='Details'):
    a,b=Vector(a),Vector(b)
    obj=box(name,(a+b)/2,(width,depth,(b-a).length),mat,group)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return obj

def tube(name,points,r,mat,group='Details',sides=8):
    verts=[];faces=[]
    for i,point in enumerate(points):
        tangent=(Vector(points[min(len(points)-1,i+1)])-Vector(points[max(0,i-1)])).normalized()
        side=tangent.cross(Vector((0,0,1)))
        if side.length<.01:side=tangent.cross(Vector((0,1,0)))
        side.normalize();up=tangent.cross(side).normalized()
        for j in range(sides):verts.append(tuple(Vector(point)+r*(side*math.cos(j*math.tau/sides)+up*math.sin(j*math.tau/sides))))
        if i:
            for j in range(sides):faces.append(((i-1)*sides+j,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    return mesh(name,verts,faces,mat,group)

# Simple buried base; textured maps are reserved for surfaces visible to the player.
box('FoundationCore',(0,0,.18),(6.04,4.62,.36),'KC_WetStone',edge=.025)
for row in range(2):
    for side in (-1,1):
        for i in range(8):
            x=-2.65+i*.76+(row%2)*.14
            box('FoundationFaceStone',(x,side*2.29,.11+row*.16),(.70,.12,.15),'KC_WetStone',edge=.015)
        for i in range(5):
            box('SideFoundationStone',(side*2.98,-1.8+i*.9,.11+row*.16),(.1,.84,.15),'KC_WetStone',edge=.015)

# Closed exterior shell: keeps existing solid Godot wall collision.
box('OpaqueWallCore',(0,0,1.65),(5.64,4.10,2.70),'KC_Cavity',edge=0)
box('FloorRim',(0,0,.43),(5.87,4.32,.16),'KC_BareTimber')
for row in range(16):
    z=.48+row*.164
    for side in (-1,1):
        # Front and rear weatherboards, staggered joints at authentic board lengths.
        join=-.85+(row%3)*.7
        for left,right in ((-2.85,join),(join+.014,2.85)):
            box('HorizontalWeatherboard',((left+right)/2,side*(2.106+row*.0005),z),(right-left,.09,.176),'KC_WeatheredPaint',edge=.006)
        for front,back in ((-2.10,-.24+(row%2)*.52),(-.22+(row%2)*.52,2.10)):
            box('SideWeatherboard',(side*2.858,(front+back)/2,z),(.09,back-front,.176),'KC_WeatheredPaint',edge=.006)
for x in (-2.86,2.86):
    for y in (-2.12,2.12):box('CornerCover',(x,y,1.74),(.17,.17,2.84),'KC_OldIvoryTrim')

# Gables and a physically layered standing-seam roof; ridge runs along X.
for side in (-1,1):
    mesh('GableBoarding',[(side*2.85,-2.12,3.06),(side*2.85,2.12,3.06),(side*2.85,0,4.20)],[(0,1,2)],'KC_WeatheredPaint')
    for i in range(12):
        y=-1.96+i*.355;h=(1-abs(y)/2.12)*1.14
        if h>.08:box('GableBatten',(side*2.89,y,3.06+h/2),(.055,.035,h),'KC_BareTimber',edge=.004)
    y=side*1.29
    angle=-side*math.atan2(1.37,2.55)
    roof=box('SteelRoofPanel',(0,y,3.56),(6.68,2.90,.075),'KC_StandingSeamSteel','Roof',.008)
    roof.rotation_euler.x=angle
    for i in range(16):
        x=-3.22+i*.43
        beam('RaisedStandingSeam',(x,side*.025,4.26),(x,side*2.56,2.90),.028,.045,'KC_StandingSeamSteel','Roof')
    for x in (-3.35,3.35):
        beam('GableBargeboard',(x,0,4.23),(x,side*2.61,2.84),.13,.15,'KC_OldIvoryTrim','Roof')
    box('EaveFascia',(0,side*2.55,2.85),(6.75,.12,.22),'KC_BareTimber','Roof')
    # Open gutter cross section, useful at the silhouette; low side count, no buried details.
    verts=[]
    for x in (-3.37,3.37):
        for j in range(7):
            t=math.pi+j*math.pi/6
            verts.append((x,side*2.64+math.cos(t)*.085,2.84+math.sin(t)*.085))
    faces=[(i,i+1,8+i,7+i) for i in range(6)]
    gutter=mesh('RainGutter',verts,faces,'KC_DullZinc','Roof')
    solid=gutter.modifiers.new('Folded sheet thickness','SOLIDIFY');solid.thickness=.004
box('FoldedRidgeCap',(0,0,4.27),(6.82,.24,.13),'KC_StandingSeamSteel','Roof',.025)

# Existing footprint and stair heights are kept for Godot's original collision.
for i in range(10):
    box('PorchDeckPlank',(-1.72+i*.382,-2.82,.35),(.367,1.16,.10),'KC_BareTimber','Porch',.006)
for y in (-2.35,-3.30):box('PorchSupportBeam',(0,y,.20),(3.84,.13,.22),'KC_BareTimber','Porch')
box('LowerStep',(0,-3.50,.10),(2.38,.40,.20),'KC_BareTimber','Porch')
for i in (-1,1):
    box('PorchPost',(i*1.65,-3.10,1.50),(.14,.14,2.72),'KC_BareTimber','Porch')
    box('PostFootShoe',(i*1.65,-3.10,.46),(.19,.19,.22),'KC_DarkIron','Porch')
    beam('PorchKneeBrace',(i*1.65,-3.10,2.18),(i*1.12,-3.10,2.72),.09,.10,'KC_BareTimber','Porch')
    box('SidePorchRail',(i*1.78,-2.86,1.22),(.10,1.08,.10),'KC_BareTimber','Porch')
    for y in (-2.45,-2.84,-3.24):box('SidePorchBaluster',(i*1.78,y,.82),(.055,.055,.74),'KC_BareTimber','Porch',.004)
awning=box('PorchCanopy',(0,-2.80,2.84),(4.15,1.75,.075),'KC_StandingSeamSteel','Roof')
awning.rotation_euler.x=math.radians(7)
for x in (-1.9,1.9):
    beam('CanopyEdge',(x,-1.95,2.97),(x,-3.65,2.76),.10,.09,'KC_OldIvoryTrim','Porch')
box('CanopyFrontFascia',(0,-3.65,2.76),(4.18,.10,.19),'KC_BareTimber','Porch')
bpy.context.scene.unit_settings.system='METRIC'
bpy.context.scene.unit_settings.scale_length=1
bpy.app.driver_namespace['KC_BUILD']=globals().copy()
print('CABIN_STRUCTURE_OK',len(COL.objects),'source objects;',len(M),'materials; only 1024/512 px maps')
