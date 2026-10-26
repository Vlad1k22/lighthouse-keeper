import bpy
globals().update(bpy.app.driver_namespace["SV_BUILD"])
# Remove the continuous gunwale across the starboard boarding gap.
for obj in list(COL.objects):
    if obj.name.startswith("SV_Gunwale"):bpy.data.objects.remove(obj,do_unlink=True)
for side in [-1,1]:
    runs=[(-7.8,10)] if side<0 else [(-7.8,-4.35),(-1.55,10)]
    for aa,bb in runs:
        tube("SV_Gunwale",[(side*width(float(y))*.98,float(y),1.065+max(0,float(y)-5.5)*.045) for y in np.linspace(aa,bb,max(3,int((bb-aa)*3)))],.045,"SV_DarkIron",10,"Hull")
# A detailed diesel set below the flush steel service grille.
box("SV_Engine_Sump",(0,-1,.32),(1.1,1.5,.3),"SV_DarkIron",.07)
box("SV_Diesel_Block",(0,-1,.55),(.88,1.25,.44),"SV_BluePaint",.055)
for y in [-1.5,-1.17,-.84,-.51]:
    box("SV_Engine_CylinderHead",(0,y,.82),(.75,.27,.17),"SV_Galvanized",.025)
    for x in [-.29,.29]:bolt("SV_Head_Bolt",(x,y,.915),.021)
    tube("SV_Injector_Pipe",[(-.32,y,.8),(-.43,y,.89),(-.45,y-.06,.94),(-.05,y-.06,.94)],.012,"SV_Brass",8)
cylinder("SV_Oil_Filter",(.46,-1.2,.4),(.46,-1.2,.77),.12,"SV_IvoryPaint",24)
cylinder("SV_Air_Filter",(-.4,-.75,.7),(-.4,-.75,.92),.18,"SV_DarkIron",24)
for y,r in [(-1.62,.20),(-.42,.13)]:
    torus("SV_Engine_Pulley",(-.53,y,.53),r,.025,"SV_Galvanized",(0,math.pi/2,0))
tube("SV_Drive_Belt",[(-.56,-1.62,.72),(-.56,-.42,.65),(-.56,-.30,.53),(-.56,-.42,.4),(-.56,-1.62,.33),(-.56,-1.82,.53),(-.56,-1.62,.72)],.023,"SV_Rubber",8)
for x in [-1.0,1.0]:
    box("SV_Hatch_Coaming",(x,-1,.99),(.06,1.82,.045),"SV_Galvanized",.012)
for y in [-1.91,-.09]:
    box("SV_Hatch_Coaming",(0,y,.99),(2.05,.06,.045),"SV_Galvanized",.012)
for x in np.linspace(-.93,.93,20):
    box("SV_Service_Grille",(float(x),-1,.994),(.025,1.77,.018),"SV_DarkIron",.004)
for y in [-1.65,-1,-.35]:
    box("SV_Grille_Crossbar",(0,y,.98),(1.92,.035,.025),"SV_Galvanized",.004)
box("SV_Engine_Ready_Lamp",(.91,-.2,1.025),(.08,.08,.035),"SV_GreenLamp",.012,"StageEngineReady")
# Broken and repaired hull/deck inspection area: separate export groups.
box("SV_Damaged_Opening",(1.1,-6.1,1.008),(1.7,1.2,.012),"SV_Interior",.005,"StageHullDamage")
for x in [.25,1.95]:
    b=box("SV_Splintered_Edge",(x,-6.1,1.026),(.12,1.28,.04),"SV_WeatheredDeck",.005,"StageHullDamage")
    b.rotation_euler.z=.08 if x<1 else -.12
for i in range(5):
    x=.44+i*.33
    plank=box("SV_Repair_Plank",(x,-6.1,1.018),(.31,1.3,.038),"SV_WeatheredDeck",.006,"StageHullRepaired")
    for y in [-6.63,-5.57]:bolt("SV_Repair_Bolt",(x,y,1.045),.024,"StageHullRepaired")
for obj in COL.objects:
    if obj.get("assembly") in ["StageHullRepaired","StageEngineReady"]:obj.hide_render=True
# Fuel tank, pipework, bolted mounting straps and a readable gauge.
cylinder("SV_Diesel_Tank",(2,.9,1.05),(2,.9,1.94),.42,"SV_BluePaint",40)
for z in [1.18,1.8]:
    torus("SV_Tank_Strap",(2,.9,z),.423,.027,"SV_Galvanized")
cylinder("SV_Fuel_Cap",(2,.9,1.95),(2,.9,2.04),.1,"SV_Brass",20)
tube("SV_Fuel_Pipe",[(2,.9,1.13),(2,.9,.89),(1.4,.9,.89),(1.4,-.3,.89),(.9,-.3,.75)],.025,"SV_DarkIron",10)
box("SV_Tank_Foot",(2,.9,1.035),(.95,.95,.07),"SV_DarkIron",.03)
for x in [1.64,2.36]:
    for y in [.54,1.26]:bolt("SV_Tank_Bolt",(x,y,1.08),.025)
lettering("SV_Tank_Label","ДТ",(2,.47,1.46),.17)
def crate(cx,cy):
    box("SV_Cargo_Inner",(cx,cy,1.43),(.84,.84,.84),"SV_Interior",.025)
    for i in range(5):
        z=1.08+i*.16
        for sy in [-1,1]:box("SV_Crate_Plank",(cx,cy+sy*.44,z),(.89,.055,.145),"SV_WeatheredDeck",.006)
        for sx in [-1,1]:box("SV_Crate_Plank",(cx+sx*.44,cy,z),(.055,.89,.145),"SV_WeatheredDeck",.006)
    for sx in [-1,1]:
        for sy in [-1,1]:box("SV_Crate_Corner",(cx+sx*.41,cy+sy*.41,1.43),(.1,.1,.92),"SV_WeatheredDeck",.008)
    for i in range(5):box("SV_Crate_Lid",(cx-.35+i*.175,cy,1.9),(.163,.9,.06),"SV_WeatheredDeck",.006)
    for y in [cy-.29,cy+.29]:
        box("SV_Crate_Band",(cx,y,1.938),(.94,.05,.025),"SV_DarkIron",.004)
crate(-2,-3.5);crate(-2,-5)
lettering("SV_Cargo_Stencil","ПРИПАСЫ",(-2,-5.457,1.39),.12)
# Tyre fenders with rope suspension, rubbed sidewalls and tread rings.
for side in [-1,1]:
    for y in [-5.8,-.1,5]:
        x=side*(width(y)+.07)
        torus("SV_Tyre_Fender",(x,y,.48),.29,.095,"SV_Rubber",(0,math.pi/2,0))
        for offset in [-.055,.055]:
            torus("SV_Tyre_Sidewall",(x+offset,y,.48),.29,.018,"SV_Rubber",(0,math.pi/2,0))
        tube("SV_Fender_Rope",[(side*width(y)*.97,y,1.18),(x+.02*side,y,.84),(x,y-.09,.65)],.023,"SV_Rope",8)
def buoy(at,rotation):
    obj=torus("SV_Lifebuoy",at,.30,.067,"SV_Orange",rotation)
    transform=obj.rotation_euler.to_matrix()
    for i in range(4):
        a=i*math.pi/2
        pts=[]
        for t in np.linspace(a-.17,a+.17,8):
            p=Vector(at)+transform@Vector((math.cos(t)*.3,math.sin(t)*.3,0))
            pts.append(tuple(p))
        tube("SV_Lifebuoy_Tape",pts,.069,"SV_Lettering",10)
    return obj
buoy((-1.45,-7.69,1.53),(math.pi/2,0,0))
buoy((1.45,-7.69,1.53),(math.pi/2,0,0))
buoy((2.23,6.7,2.35),(0,math.pi/2,0))
# Mooring bollards, cleats, capstan, anchor and chain.
for side in [-1,1]:
    for y in [-6.8,7.8]:
        x=side*width(y)*.73
        box("SV_Bollard_Foot",(x,y,1.03),(.42,.5,.07),"SV_DarkIron",.025)
        for dy in [-.12,.12]:
            cylinder("SV_Bollard",(x,y+dy,1.04),(x,y+dy,1.32),.07,"SV_Galvanized",16)
        cylinder("SV_Bollard_Crossbar",(x-.22,y,1.28),(x+.22,y,1.28),.055,"SV_Galvanized",16)
cylinder("SV_Windlass",(0,8.4,1.06),(0,8.4,1.48),.25,"SV_BluePaint",32)
cylinder("SV_Windlass_Cap",(0,8.4,1.48),(0,8.4,1.58),.33,"SV_Galvanized",32)
for y in np.linspace(8.5,9.5,12):
    torus("SV_Anchor_Chain",(0,float(y),1.15),.06,.015,"SV_DarkIron",(0,math.pi/2 if int(y*10)%2 else 0,0))
cylinder("SV_Anchor_Shaft",(-1.5,9.1,.65),(-1.5,9.1,-.13),.055,"SV_Galvanized",16)
torus("SV_Anchor_Shackle",(-1.5,9.1,.72),.1,.025,"SV_DarkIron",(math.pi/2,0,0))
for sx in [-1,1]:
    tube("SV_Anchor_Arm",[(-1.5,9.1,-.13),(-1.5+sx*.38,9.1,-.06),(-1.5+sx*.48,9.1,.2)],.045,"SV_Galvanized",10)
    fluke=box("SV_Anchor_Fluke",(-1.5+sx*.41,9.1,.13),(.21,.28,.055),"SV_Galvanized",.01)
    fluke.rotation_euler.y=sx*-.6
for center in [(-1.2,-6.65),(2.1,-5.8)]:
    pts=[]
    for a in np.linspace(0,math.tau*4,220):
        r=.07+a*.012
        pts.append((center[0]+math.cos(a)*r,center[1]+math.sin(a)*r,1.048))
    tube("SV_Rope_Coil",pts,.023,"SV_Rope",8)
# Extinguisher, access ladder, horn, deck work lamps and cable clips.
cylinder("SV_Extinguisher",(1.7,3.72,1.2),(1.7,3.72,1.75),.115,"SV_Orange",24)
torus("SV_Extinguisher_Collar",(1.7,3.72,1.78),.09,.025,"SV_DarkIron")
tube("SV_Extinguisher_Hose",[(1.72,3.72,1.8),(1.88,3.72,1.78),(1.89,3.72,1.3)],.024,"SV_Rubber",8)
for x in [-1.7,-1.2]:cylinder("SV_Roof_Ladder",(x,7.66,1.2),(x,7.66,3.3),.03,"SV_Galvanized",12)
for z in np.linspace(1.3,3.2,8):cylinder("SV_Ladder_Rung",(-1.7,7.7,float(z)),(-1.2,7.7,float(z)),.027,"SV_Galvanized",12)
for x in [-1.6,1.6]:
    box("SV_Deck_Worklight",(x,3.65,3.23),(.35,.25,.23),"SV_DarkIron",.05)
    box("SV_Worklight_Glass",(x,3.51,3.23),(.25,.016,.14),"SV_Lettering",.02)
# Side draft marks and warning placards remain geometry, so lettering survives glTF.
for z in [.15,.35,.55]:
    lettering("SV_Draft_Mark",str(int((z+1)*10)),(-2.83,-7.82,z),.09)
box("SV_Engine_Plaque",(.9,-.15,1.035),(.45,.20,.012),"SV_Brass",.006)
lettering("SV_Engine_Label","ДИЗЕЛЬ",(.9,-.16,1.044),.06,(0,0,0),"SV_DarkIron")
bpy.app.driver_namespace["SV_BUILD"].update(globals())
print("EQUIPMENT_OK",len(COL.objects),"editable source objects; repair variants, engine, fenders, tackle, fittings complete")
