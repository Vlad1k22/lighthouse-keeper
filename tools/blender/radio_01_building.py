"""A26-A28 radio outpost. Run in a dedicated Blender scene through MCP."""
import bpy, math, random, json, os, ast
import numpy as np
from pathlib import Path
from mathutils import Vector
PROJECT=r'C:\Users\Redmi\Documents\Codex\2026-09-28\x20\outputs\lighthouse-keeper'
SOURCE=PROJECT+'/assets/source_blender/radio_station'
EXPORT=PROJECT+'/assets/models/radio_station'
PREVIEW=PROJECT+'/docs/art/radio_station'
for path in (SOURCE,EXPORT,PREVIEW):os.makedirs(path,exist_ok=True)
if bpy.data.filepath and 'radio_station' not in bpy.data.filepath:
    raise RuntimeError('Create a dedicated new Blender file; preserve the other assets.')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name=='Collection':bpy.data.collections.remove(collection)
COL=bpy.data.collections.new('RS_SOURCE_EDITABLE');bpy.context.scene.collection.children.link(COL)
ROOT=bpy.data.objects.new('RS_RadioStation',None);COL.objects.link(ROOT)
ROOT['asset_id']='A26-A28_radio_station_v01'
ROOT['created_via']='Blender 5.2.2 LTS / MCP for Blender 2.2.4'
ROOT['origin']='Godot (-12, 1, -39.5); Blender Z-up, front -Y -> Godot Y-up, front +Z'
ROOT['scope']='Exterior radio hut, mast, guy wires, transmitter and repair-state variants'
M={};rng=random.Random(2628)
# Reuse actual Blender authoring helpers; only function definitions are loaded, not the cabin model.
helper_path=Path(PROJECT)/'tools/blender/cabin_01_structure.py'
tree=ast.parse(helper_path.read_text(encoding='utf-8'))
helpers=ast.Module(body=[node for node in tree.body if isinstance(node,ast.FunctionDef)],type_ignores=[])
exec(compile(helpers,str(helper_path),'exec'),globals())

def plaster():
    n=1024
    mat=material('RS_SaltWornPlaster','777767',.94)
    a=noise(n,9,226);b=noise(n,60,227);c=noise(n,250,228)
    yy,xx=np.mgrid[0:n,0:n].astype(np.float32)/n
    damp=ramp(.42,.76,a*.7+b*.3)
    salt=ramp(.60,.8,b*.6+c*.4)
    base=np.array(rgb('777767'))[None,None,:]*(.78+a[:,:,None]*.22+c[:,:,None]*.08)
    base=base*(1-damp[:,:,None]*.3)+np.array(rgb('a7a18b'))[None,None,:]*salt[:,:,None]*.07
    height=a*.04+b*.035+c*.055
    gy,gx=np.gradient(height)
    normal=np.stack([-gx*20,-gy*20,np.ones_like(a)],axis=-1)
    normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    maps=[image('RS_SaltWornPlaster_BaseColor',np.clip(base,0,1)),
          image('RS_SaltWornPlaster_Normal',normal*.5+.5,True),
          image('RS_SaltWornPlaster_ORM',np.stack([np.ones_like(a),.85+c*.12,np.zeros_like(a)],axis=-1),True)]
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
    tx=nt.nodes.new('ShaderNodeTexImage');tx.image=maps[0];nt.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    tx=nt.nodes.new('ShaderNodeTexImage');tx.image=maps[1]
    nm=nt.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.35
    nt.links.new(tx.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    tx=nt.nodes.new('ShaderNodeTexImage');tx.image=maps[2];sep=nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(tx.outputs['Color'],sep.inputs['Color']);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness'])
plaster()
textured('RS_WeatheredSteel','52605b',1024,'roof',326)
textured('RS_ExposedBrick','786151',512,'brick',426)
material('RS_DarkIron','303735',.67,.65)
material('RS_Galvanized','79857e',.52,.75)
material('RS_FadedIvory','a5a18c',.85)
material('RS_Rubber','202824',.96)
material('RS_Concrete','5f635c',.94)
material('RS_Cavity','1b2422',.96)
material('RS_Brass','9b855b',.44,.68)
material('RS_DialFace','aaa68e',.88)
material('RS_DialGlass','3a514b',.2,.1)
material('RS_DialGlow','719176',.55,0,.5)
material('RS_FaultAmber','bc7443',.5,0,1.2)
material('RS_ReadyGreen','709e79',.4,0,1.3)
material('RS_MastBeacon','a9513f',.5,0,.7)
material('RS_Warning','b5a270',.85)

# Original hut footprint: 5 x 3.7m; an exterior-only utility building.
box('FoundationPlinth',(0,0,.12),(5.12,3.82,.24),'RS_Concrete','Hut',.025)
box('PlasterWalls',(0,0,1.25),(5,3.7,2.30),'RS_SaltWornPlaster','Hut',.025)
for side in (-1,1):
    box('DampProofBase',(0,side*1.858,.28),(4.96,.045,.30),'RS_Concrete','Hut',.005)
    box('WallCornerFlashing',(side*2.49,-1.86,1.26),(.085,.055,2.32),'RS_DarkIron','Hut',.005)
    for x in (-1.7,0,1.7):box('WallPanelJoint',(x,side*1.877,1.29),(.016,.012,2.17),'RS_Cavity','Hut',0)
    # Sparse large brick exposures at the foot, rather than high-resolution hidden walls.
    for j in range(2):box('ExposedMasonry',(side*(1.7+j*.32),-1.883,.54+j*.13),(.56,.025,.26),'RS_ExposedBrick','Hut',.005)
roof=box('MonoPitchRoof',(0,.04,2.55),(5.57,4.32,.09),'RS_WeatheredSteel','Roof',.008)
roof.rotation_euler.x=math.atan2(.34,4.3)
for i in range(14):
    x=-2.68+i*.415
    beam('RoofStandingSeam',(x,-2.11,2.42),(x,2.19,2.76),.025,.04,'RS_WeatheredSteel','Roof')
for side in (-1,1):
    beam('SideRoofFascia',(side*2.80,-2.14,2.34),(side*2.80,2.22,2.68),.10,.16,'RS_DarkIron','Roof')
box('FrontDripEdge',(0,-2.14,2.34),(5.65,.10,.13),'RS_Galvanized','Roof')
box('RearRoofFascia',(0,2.20,2.68),(5.65,.10,.13),'RS_DarkIron','Roof')
tube('Downpipe',[(-2.61,-2.15,2.36),(-2.61,-2.15,2.06),(-2.53,-1.89,1.91),(-2.53,-1.89,.30),(-2.53,-2.07,.19)],.045,'RS_Galvanized','Hut')

# Service door to the east of the external transmitter; source geometry stays independent.
box('ServiceDoor',(1.45,-1.89,1.17),(.88,.08,2.04),'RS_WeatheredSteel','Hut')
for x in (.95,1.95):box('DoorFrame',(x,-1.93,1.22),(.10,.14,2.17),'RS_DarkIron','Hut')
box('DoorLintel',(1.45,-1.93,2.31),(1.13,.14,.10),'RS_DarkIron','Hut')
box('Threshold',(1.45,-1.98,.17),(1.08,.32,.07),'RS_Galvanized','Hut')
for z in (.53,1.65):
    box('DoorStrap',(1.12,-1.95,z),(.30,.028,.06),'RS_DarkIron','Hut',.004)
    cylinder('DoorHinge',(1.0,-1.97,z-.06),(1.0,-1.97,z+.06),.022,'RS_Galvanized','Hut')
box('DoorHandlePlate',(1.78,-1.96,1.12),(.08,.025,.21),'RS_Galvanized','Hut')
tube('DoorPull',[(1.78,-1.98,1.04),(1.78,-2.06,1.04),(1.78,-2.06,1.18),(1.78,-1.98,1.18)],.016,'RS_DarkIron','Hut')
for i in range(6):box('DoorVentLouvre',(1.45,-1.955,.38+i*.055),(.54,.025,.028),'RS_DarkIron','Hut',.002)

# One recessed inspection window. Dark backing avoids an expensive inaccessible room.
box('InspectionRecess',(-1.30,-1.875,1.61),(1.06,.025,.72),'RS_Cavity','Hut')
box('InspectionGlass',(-1.30,-1.90,1.61),(.91,.02,.59),'RS_DialGlass','Hut',.003)
for x in (-1.85,-.75):box('WindowJamb',(x,-1.93,1.61),(.075,.10,.81),'RS_FadedIvory','Hut')
for z in (1.22,2.0):box('WindowHeader',(-1.3,-1.93,z),(1.18,.1,.08),'RS_FadedIvory','Hut')
for x in (-1.60,-1.30,-1.0):cylinder('WindowSecurityBar',(x,-2.0,1.22),(x,-2.0,2.0),.015,'RS_DarkIron','Hut',10)
box('WindowSill',(-1.3,-1.99,1.19),(1.29,.30,.055),'RS_Galvanized','Hut')

# Visible ventilation and earthing details on the right wall.
box('VentHousing',(2.53,.65,1.70),(.20,1.25,.60),'RS_WeatheredSteel','Hut')
for i in range(8):box('VentSlat',(2.64,.65,1.46+i*.062),(.025,1.13,.025),'RS_DarkIron','Hut',.002)
for z in (.45,1.05,1.65):box('EarthingStrap',(2.525,-1.15,z),(.016,.055,.48),'RS_Brass','Hut',.002)
box('GroundRodBox',(2.55,-1.15,.23),(.15,.28,.20),'RS_DarkIron','Hut')
for side in (-1,1):
    box('RoofCornerClamp',(side*2.30,-2.11,2.45),(.15,.12,.05),'RS_Galvanized','Roof',.004)

bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
bpy.app.driver_namespace['RS_BUILD']=globals().copy()
print('RADIO_BUILDING_OK',len(COL.objects),'source objects;',len(M),'materials; MCP-authored')
