import bpy
globals().update(bpy.app.driver_namespace['RS_BUILD'])

# Tapered triangular tower; front +Z in Godot, independently grouped for reuse.
cx,cy=-4.0,.50
def corners(z):
    scale=1-z/14
    return [Vector((cx+dx*scale,cy+dy*scale,z)) for dx,dy in [(-.40,-.24),(.40,-.24),(0,.45)]]
box('MastConcreteBase',(cx,cy,.09),(1.12,1.10,.18),'RS_Concrete','Mast')
for p in corners(.19):
    box('MastFootPlate',(p.x,p.y,.205),(.20,.20,.04),'RS_DarkIron','Mast')
    for dx in (-.065,.065):cylinder('MastAnchorBolt',(p.x+dx,p.y,.22),(p.x+dx,p.y,.28),.018,'RS_Galvanized','Mast',6)
for i in range(3):
    cylinder('TaperedMastLeg',corners(.23)[i],corners(8.75)[i],.042,'RS_Galvanized','Mast',12)
for level in range(11):
    bottom=.3+level*.76;top=bottom+.76
    low,high=corners(bottom),corners(top)
    for i in range(3):
        j=(i+1)%3
        cylinder('MastHorizontalBrace',low[i],low[j],.024,'RS_DarkIron','Mast',8)
        cylinder('MastDiagonalBrace',low[i] if level%2 else low[j],high[j] if level%2 else high[i],.022,'RS_Galvanized','Mast',8)
    for p in low:
        box('BraceConnector',(p.x,p.y,bottom),(.09,.07,.13),'RS_DarkIron','Mast',.004)
for x in (cx-.18,cx+.18):cylinder('LadderSide',(x,.10,.35),(x,.10,8.60),.022,'RS_DarkIron','Mast',10)
for i in range(27):cylinder('LadderRung',(cx-.18,.085,.48+i*.30),(cx+.18,.085,.48+i*.30),.018,'RS_Galvanized','Mast',8)
for z in (3.5,4.5,5.5,6.5,7.5,8.5):
    points=[(cx+math.cos(t)*.37,.12+math.sin(t)*.37,z) for t in np.linspace(math.pi,math.tau,13)]
    tube('LadderSafetyHoop',points,.016,'RS_DarkIron','Mast')
for x in (cx-.33,cx+.33):cylinder('CageVertical',(x,-.06,3.5),(x,-.06,8.5),.014,'RS_DarkIron','Mast',8)

# Directional aerial and a second receive dipole, with a readable antenna silhouette.
cylinder('UpperAntennaShaft',(cx,cy,8.5),(cx,cy,9.55),.036,'RS_Galvanized','Antenna',12)
cylinder('TopWhip',(cx,cy,9.55),(cx,cy,10.05),.012,'RS_DarkIron','Antenna',8)
cylinder('DirectionalBoom',(cx,-1.15,8.04),(cx,1.70,8.04),.035,'RS_DarkIron','Antenna',10)
for i in range(7):
    y=-1.05+i*.43;half=1.42-i*.075
    cylinder('YagiElement',(cx-half,y,8.08),(cx+half,y,8.08),.023,'RS_Galvanized','Antenna',10)
    box('ElementClamp',(cx,y,8.06),(.11,.11,.10),'RS_DarkIron','Antenna',.004)
cylinder('LowerCrossarm',(cx-1.25,cy,6.65),(cx+1.25,cy,6.65),.034,'RS_Galvanized','Antenna',10)
for sign in (-1,1):
    x=cx+sign*1.15
    cylinder('VerticalReceiveDipole',(x,cy,6.05),(x,cy,7.25),.022,'RS_Galvanized','Antenna',10)
    box('DipoleInsulator',(x,cy,6.65),(.07,.09,.14),'RS_Rubber','Antenna',.004)
box('AerialFeedBox',(cx,-.56,8.06),(.20,.28,.18),'RS_WeatheredSteel','Antenna')
tube('UpperCoax',[(cx,-.56,8.0),(cx+.12,-.38,7.86),(cx+.12,.37,7.8),(cx+.12,.37,.65)],.018,'RS_Rubber','Cables')
for z in (1,2.5,4,5.5,7):box('CoaxClip',(cx+.12,.40,z),(.10,.08,.035),'RS_DarkIron','Mast',.003)
cylinder('AviationBeaconBase',(cx,cy,8.75),(cx,cy,8.95),.10,'RS_DarkIron','Antenna')
cylinder('AviationBeaconGlass',(cx,cy,8.95),(cx,cy,9.10),.075,'RS_MastBeacon','Antenna')

# Three original guy-wire anchors remain in their established map positions.
anchors=[(-7,2.5),(-2,4.5),(-5,-3.5)]
for index,(x,y) in enumerate(anchors):
    box('GuyAnchorConcrete',(x,y,.08),(.45,.52,.16),'RS_Concrete','Cables')
    cylinder('GroundAnchorEye',(x,y,.12),(x,y,.34),.032,'RS_DarkIron','Cables',10)
    high=Vector((cx,cy,7.0));low=Vector((x,y,.31));axis=(high-low).normalized()
    cylinder('GuyWire',low,high,.010,'RS_Galvanized','Cables',6)
    a=low+axis*.16;b=low+axis*.40
    cylinder('Turnbuckle',a,b,.026,'RS_DarkIron','Cables',8)
    cylinder('TurnbuckleThread',low+axis*.07,low+axis*.49,.012,'RS_Galvanized','Cables',8)
tube('CoaxToHut',[(cx+.12,.37,.65),(-3.4,.37,.65),(-3.2,.37,.20),(-2.6,.37,.20),(-2.55,.37,.72),(-2.55,-1.98,.72),(-.78,-1.98,.72),(-.78,-2.62,.55)],.023,'RS_Rubber','Cables')
box('ExternalCableJunction',(-2.57,-1.42,1.10),(.15,.34,.44),'RS_WeatheredSteel','Hut')

# Weatherproof external transmitter: dimensions match the existing tested Godot console.
for x in (-.73,.73):box('CabinetFoot',(x,-2.80,.10),(.18,.45,.20),'RS_DarkIron','Transmitter')
box('TransmitterCase',(0,-2.8,.72),(1.90,.70,1.14),'RS_WeatheredSteel','Transmitter')
box('TransmitterPedestal',(0,-2.8,.22),(1.98,.76,.12),'RS_DarkIron','Transmitter')
box('CabinetRainHood',(0,-2.82,1.34),(2.12,.92,.07),'RS_WeatheredSteel','Transmitter')
box('FrontRecess',(0,-3.157,.82),(1.75,.028,.86),'RS_Cavity','Transmitter')
box('ControlFace',(-.24,-3.18,.87),(1.19,.035,.69),'RS_FadedIvory','Transmitter')
box('MeterFrame',(-.43,-3.21,1.045),(.63,.040,.27),'RS_DarkIron','Transmitter')
box('MeterFace',(-.43,-3.235,1.045),(.56,.018,.20),'RS_DialFace','Transmitter')
for i in range(9):
    angle=-1.05+i*.26
    x=-.43+math.sin(angle)*.24;z=.995+math.cos(angle)*.12
    box('MeterTick',(x,-3.248,z),(.009,.004,.028),'RS_DarkIron','Transmitter',.001)
beam('MeterNeedle',(-.43,-3.26,.99),(-.33,-3.26,1.11),.008,.008,'RS_DarkIron','Transmitter')
box('FrequencyWindow',(-.40,-3.22,.76),(.70,.025,.12),'RS_DialGlass','Transmitter')
for x in (-.67,-.29,.10):
    cylinder('TuningKnob',(x,-3.205,.54),(x,-3.29,.54),.070,'RS_DarkIron','Transmitter',20)
    box('KnobIndex',(x,-3.30,.582),(.011,.006,.037),'RS_FadedIvory','Transmitter',.002)
for x in (-.79,.29):
    for z in (.48,1.24):cylinder('PanelScrew',(x,-3.20,z),(x,-3.224,z),.013,'RS_Galvanized','Transmitter',6)
box('SpeakerFrame',(.64,-3.20,1.085),(.36,.045,.31),'RS_DarkIron','Transmitter')
for i in range(6):box('SpeakerLouvre',(.64,-3.23,.965+i*.048),(.30,.022,.015),'RS_Galvanized','Transmitter',.002)
box('BatteryBay',(.62,-3.18,.58),(.47,.045,.50),'RS_Cavity','Transmitter')
for x in (.36,.88):box('BatteryBayLip',(x,-3.22,.57),(.045,.06,.53),'RS_DarkIron','Transmitter')
box('BatteryShelf',(.62,-3.27,.34),(.57,.22,.065),'RS_Galvanized','Transmitter')
box('InstalledBattery',(.62,-3.25,.52),(.40,.24,.31),'RS_Rubber','BatteryInstalled')
box('BatteryTop',(.62,-3.25,.685),(.42,.25,.035),'RS_DarkIron','BatteryInstalled')
for x in (.48,.76):cylinder('BatteryTerminal',(x,-3.25,.70),(x,-3.25,.75),.022,'RS_Brass','BatteryInstalled',10)
tube('BatteryPositive',[(.48,-3.25,.75),(.47,-3.11,.80),(.38,-3.1,.83)],.013,'RS_FaultAmber','BatteryInstalled')
tube('BatteryNegative',[(.76,-3.25,.75),(.78,-3.12,.80),(.84,-3.10,.86)],.013,'RS_Rubber','BatteryInstalled')
tube('MicrophoneLead',[(-.94,-3.10,1.10),(-1.02,-3.10,.75),(-1.04,-3.10,.36),(-.94,-3.12,.28),(-.83,-3.15,.31)],.016,'RS_Rubber','Transmitter')
box('HandMicrophone',(-.97,-3.11,1.06),(.14,.11,.25),'RS_DarkIron','Transmitter')
for z in (1.02,1.06,1.10):box('MicGrille',(-.97,-3.174,z),(.095,.01,.012),'RS_Galvanized','Transmitter',.001)
box('StatusFaultLamp',(.14,-3.23,1.105),(.09,.016,.065),'RS_FaultAmber','PanelFault')
box('StatusReadyLamp',(.14,-3.23,1.105),(.09,.016,.065),'RS_ReadyGreen','PanelOnline')
box('FrequencyBacklight',(-.40,-3.242,.76),(.66,.010,.08),'RS_DialGlow','PanelOnline')

font_path='C:/Windows/Fonts/segoeui.ttf'
font=bpy.data.fonts.load(font_path) if os.path.exists(font_path) else None
def label(name,text,at,size,mat='RS_FadedIvory',group='Transmitter'):
    data=bpy.data.curves.new(name+'_Font','FONT');data.body=text;data.align_x='CENTER';data.size=size;data.extrude=.0007;data.resolution_u=4
    if font:data.font=font
    obj=bpy.data.objects.new(name,data);COL.objects.link(obj);obj.parent=ROOT;obj['assembly']=group
    obj.location=at;obj.rotation_euler.x=math.pi/2;data.materials.append(M[mat]);return obj
box('OutpostSignBack',(-.90,-1.94,2.18),(2.20,.03,.26),'RS_DarkIron','Hut')
label('OutpostSign','ПОСТ СВЯЗИ 04',(-.90,-1.964,2.115),.16,group='Hut')
label('Frequency1046','104.6',(-.40,-3.254,.725),.08)
label('TransmitterName','БЕРЕГ  /  Р-04',(-.26,-3.219,1.205),.066,'RS_DarkIron')
label('FaultLabel','НЕТ СВЯЗИ',(-.24,-3.231,.36),.065,'RS_FaultAmber','PanelFault')
label('OnlineLabel','СВЯЗЬ ЕСТЬ',(-.24,-3.231,.36),.065,'RS_ReadyGreen','PanelOnline')
box('ElectricalWarningPlate',(1.45,-1.95,1.69),(.36,.025,.28),'RS_Warning','Hut')
label('DangerSymbol','!',(1.45,-1.97,1.62),.19,'RS_DarkIron','Hut')
# Letter geometry is portable in the saved source and GLB; no system font dependency at runtime.
for obj in list(COL.objects):
    if obj.type=='FONT':
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
bpy.app.driver_namespace['RS_BUILD'].update(globals())
print('RADIO_MAST_TRANSMITTER_OK',len(COL.objects),'editable parts; separate fault/online/battery variants')
