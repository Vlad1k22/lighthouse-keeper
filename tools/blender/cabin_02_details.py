import bpy
globals().update(bpy.app.driver_namespace['KC_BUILD'])

# Correct the left gable's exterior winding while preserving editable source parts.
for obj in COL.objects:
    if obj.name.startswith('GableBoarding') and obj.data.vertices[0].co.x < 0:
        import bmesh
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()

glass=M['KC_WindowGlass'];glass.surface_render_method='DITHERED'
glass.diffuse_color=(*rgb('33413d'),.30)
bs=glass.node_tree.nodes.get('Principled BSDF')
bs.inputs['Alpha'].default_value=.30
bs.inputs['Coat Weight'].default_value=.6

def front_window(name,x,y,z,width=1.0,height=1.06,side=False):
    # Work in local window coordinates: depth points outwards, no fully detailed room behind it.
    created=[]
    def wb(n,at,size,mat,edge=.008):
        obj=box(name+'_'+n,at,size,mat,'Windows',edge);created.append(obj);return obj
    wb('DarkRecess',(0,0,0),(width,.055,height),'KC_Cavity')
    wb('WarmCurtainBacking',(0,-.035,.02),(width-.08,.025,height-.08),'KC_WindowWarm')
    # Flat curtain folds, enough visible depth for the isometric camera.
    for sign in (-1,1):
        for j in range(3):wb('CurtainFold',(sign*(width*.36-j*.055),-.065,.02),(.045,.025,height-.10),'KC_Cloth',.003)
    wb('Glass',(0,-.090,0),(width-.08,.010,height-.09),'KC_WindowGlass',0)
    for sign in (-1,1):
        wb('Jamb',(sign*(width/2+.04),-.10,0),(.10,.13,height+.20),'KC_OldIvoryTrim')
        wb('Sash',(sign*(width/2-.065),-.12,0),(.045,.065,height-.06),'KC_BareTimber',.004)
        wb('Lintel',(0,-.10,sign*(height/2+.055)),(width+.18,.14,.10),'KC_OldIvoryTrim')
    wb('CenterMullion',(0,-.135,0),(.045,.04,height-.02),'KC_BareTimber',.003)
    wb('Crossbar',(0,-.135,.08),(width-.02,.04,.045),'KC_BareTimber',.003)
    wb('SlopedSill',(0,-.16,-height/2-.10),(width+.31,.35,.10),'KC_BareTimber')
    wb('DripCap',(0,-.16,height/2+.14),(width+.29,.31,.035),'KC_DullZinc',.003)
    if not side:
        for sign in (-1,1):
            for j in range(3):
                wb('ShutterBoard',(sign*(width/2+.27)+j*.10-.10,-.06,0),(.092,.065,height+.14),'KC_WeatheredPaint',.004)
            for h in (-.34,.34):wb('ShutterStrap',(sign*(width/2+.27),-.11,h),(.29,.024,.040),'KC_DarkIron',.003)
    for obj in created:
        co=obj.location.copy()
        if side:
            # Local -Y (outwards) rotates to +X on the east wall, or -X on west.
            ang=math.pi/2 if x>0 else -math.pi/2
            co.rotate(__import__('mathutils').Matrix.Rotation(ang,3,'Z'))
            obj.rotation_euler.z=ang
        elif y>0:
            co.x=-co.x;co.y=-co.y;obj.rotation_euler.z=math.pi
        obj.location=co+Vector((x,y,z))

for x in (-1.70,1.70):front_window('FrontWindow',x,-2.17,1.74,.93,1.02)
front_window('EastWindow',2.91,.45,1.78,1.12,1.12,True)
front_window('WestWindow',-2.91,.58,1.78,.93,1.02,True)
front_window('RearWindow',-.85,2.17,1.80,.91,1.0)

# A separate door assembly and sensible hinge origin are retained for later animation.
door=box('DoorSlab',(0,-2.23,1.48),(.96,.10,2.13),'KC_WeatheredPaint','Door',.012)
for x in (-.56,.56):box('DoorJamb',(x,-2.24,1.50),(.13,.20,2.30),'KC_OldIvoryTrim')
box('DoorHeader',(0,-2.24,2.66),(1.26,.20,.14),'KC_OldIvoryTrim')
box('DoorThreshold',(0,-2.30,.43),(1.16,.37,.08),'KC_DullZinc')
box('DoorKickPlate',(0,-2.30,.61),(.86,.024,.24),'KC_DullZinc','Door',.004)
box('DoorGlassRecess',(0,-2.292,1.91),(.58,.024,.62),'KC_Cavity','Door')
box('DoorWarmGlass',(0,-2.31,1.91),(.49,.014,.53),'KC_WindowWarm','Door',.002)
for x in (-.28,.28):box('DoorGlassBead',(x,-2.33,1.91),(.035,.03,.62),'KC_BareTimber','Door',.002)
for z in (1.62,2.20):box('DoorGlassBead',(0,-2.33,z),(.59,.03,.035),'KC_BareTimber','Door',.002)
box('DoorWindowBar',(0,-2.34,1.91),(.032,.03,.59),'KC_BareTimber','Door',.002)
for x in (-.34,.34):box('DoorLowerStile',(x,-2.295,1.04),(.045,.025,.64),'KC_BareTimber','Door',.003)
for z in (.73,1.35):box('DoorPanelRail',(0,-2.295,z),(.70,.025,.045),'KC_BareTimber','Door',.003)
for z in (.80,1.94):
    box('StrapHinge',(-.29,-2.32,z),(.43,.028,.065),'KC_DarkIron','Door',.006)
    cylinder('HingePin',(-.49,-2.33,z-.06),(-.49,-2.33,z+.06),.026,'KC_DarkIron','Door',10)
    for x in (-.42,-.15):cylinder('HingeBolt',(x,-2.34,z),(x,-2.36,z),.016,'KC_DullZinc','Door',6)
box('HandleBackplate',(.34,-2.32,1.30),(.09,.025,.21),'KC_Brass','Door')
tube('DoorLever',[(.34,-2.34,1.33),(.34,-2.41,1.33),(.22,-2.41,1.33)],.018,'KC_Brass','Door')
box('Keyhole',(.34,-2.342,1.24),(.015,.005,.035),'KC_Cavity','Door',.002)

# Brick chimney, flashing, cap and rain hood align with the existing Godot smoke emitter.
box('ChimneyStack',(1.6,.6,4.08),(.53,.58,2.00),'KC_ChimneyBrick','Chimney',.018)
box('ChimneyShoulder',(1.6,.6,4.94),(.65,.69,.11),'KC_WetStone','Chimney')
box('ChimneySootMouth',(1.6,.6,5.02),(.40,.42,.04),'KC_Cavity','Chimney',.003)
box('ChimneyRainCap',(1.6,.6,5.15),(.77,.78,.055),'KC_DarkIron','Chimney')
for x in (1.35,1.85):
    for y in (.36,.84):cylinder('CapLeg',(x,y,4.97),(x,y,5.14),.014,'KC_DarkIron','Chimney',8)
box('ChimneyFlashing',(1.6,.6,3.98),(.78,.87,.10),'KC_DullZinc','Chimney')
for side in (-1,1):
    x=side*3.02;y=side*2.64
    tube('RainDownpipe',[(x,y,2.80),(x,y,2.45),(x,side*2.25,2.30),(x,side*2.25,.45),(x,side*2.44,.27)],.045,'KC_DullZinc')
    for z in (.65,1.7,2.4):box('PipeBracket',(x,side*2.21,z),(.16,.12,.035),'KC_DarkIron','Details',.004)

# Visible lived-in details; no hidden machinery or dense interior props.
box('Nameplate',(1.02,-2.25,2.34),(.40,.05,.23),'KC_DarkIron')
font=bpy.data.curves.new('NameplateLettering','FONT');font.body='04';font.align_x='CENTER';font.size=.14;font.extrude=.001
obj=bpy.data.objects.new('CabinNumber04',font);COL.objects.link(obj);obj.parent=ROOT;obj['assembly']='Details'
obj.location=(1.02,-2.283,2.29);obj.rotation_euler.x=math.pi/2;font.materials.append(M['KC_OldIvoryTrim'])
box('PorchBootScraper',(-.86,-3.12,.48),(.40,.24,.035),'KC_DarkIron','Porch',.003)
for x in (-1.04,-.68):box('ScraperFoot',(x,-3.12,.43),(.025,.20,.10),'KC_DarkIron','Porch',.003)
for x in (-1.15,-.87,-.59):
    cylinder('CoatHook',(x,-2.24,2.23),(x,-2.38,2.23),.014,'KC_DarkIron')
box('ElectricalFuseBox',(2.94,-.80,1.72),(.13,.35,.52),'KC_DarkIron')
box('FuseBoxCover',(3.018,-.80,1.72),(.022,.29,.46),'KC_DullZinc')
tube('WallCable',[(2.93,-.72,1.99),(2.93,-.72,2.68),(2.93,-1.8,2.70),(2.7,-2.18,2.70),(1.0,-2.18,2.70)],.012,'KC_DarkIron')
for y in (-1.3,.0,1.3):box('StormAnchorPlate',(2.926,y,.63),(.025,.18,.22),'KC_DarkIron')
for x in (-2.35,2.35):
    box('WindBracePlate',(x,-2.18,2.76),(.22,.026,.22),'KC_DarkIron')
    for dx in (-.06,.06):cylinder('BraceBolt',(x+dx,-2.20,2.76),(x+dx,-2.23,2.76),.018,'KC_DullZinc',sides=6)

# Enclosed entry lantern: mesh glass only; actual dynamic light lives in Godot.
box('LanternWallPlate',(.94,-2.25,2.08),(.14,.07,.29),'KC_DarkIron')
tube('LanternHanger',[(.94,-2.25,2.23),(.94,-2.51,2.23),(.94,-2.51,2.11)],.023,'KC_DarkIron')
box('LanternGlow',(.94,-2.51,1.95),(.16,.14,.22),'KC_LanternGlass')
for x in (.83,1.05):
    for y in (-2.61,-2.41):box('LanternCage',(x,y,1.95),(.023,.023,.27),'KC_DarkIron',edge=.003)
box('LanternTop',(.94,-2.51,2.105),(.27,.24,.055),'KC_DarkIron')
box('LanternFoot',(.94,-2.51,1.80),(.24,.22,.045),'KC_DarkIron')

# A handful of large cracks, not thousands of bolts invisible from the game camera.
for x,z in ((-2.37,.9),(2.42,1.23),(1.18,.56),(-.86,2.70)):
    mesh('SplitInWeatherboard',[(x,-2.158,z),(x+.32,-2.158,z+.008),(x+.15,-2.162,z-.018)],[(2,1,0)],'KC_Cavity','Details')

for obj in COL.objects:
    if obj.type=='FONT':
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
bpy.app.driver_namespace['KC_BUILD'].update(globals())
print('CABIN_DETAILS_OK',len(COL.objects),'editable objects; exterior only; shared PBR maps')
