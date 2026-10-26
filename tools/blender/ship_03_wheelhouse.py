import bpy
globals().update(bpy.app.driver_namespace["SV_BUILD"])
glass=M["SV_Glass"]
glass.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(.12,.20,.20,.35)
glass.surface_render_method="DITHERED"
glass.use_backface_culling=False
def window(name,center,w,h,axis="Y"):
    x,y,z=center
    if axis=="Y":
        pane=box(name,(x,y,z),(w,.026,h),"SV_Glass",.018,"Wheelhouse")
        for sx in [-1,1]:
            box("SV_Window_Frame",(x+sx*(w+.05)/2,y-.008,z),(.065,.065,h+.14),"SV_DarkIron",.018,"Wheelhouse")
        for sz in [-1,1]:
            box("SV_Window_Frame",(x,y-.008,z+sz*(h+.05)/2),(w+.14,.065,.065),"SV_DarkIron",.018,"Wheelhouse")
    else:
        pane=box(name,(x,y,z),(.026,w,h),"SV_Glass",.018,"Wheelhouse")
        for sy in [-1,1]:
            box("SV_Window_Frame",(x,y+sy*(w+.05)/2,z),(.065,.065,h+.14),"SV_DarkIron",.018,"Wheelhouse")
        for sz in [-1,1]:
            box("SV_Window_Frame",(x,y,z+sz*(h+.05)/2),(.065,w+.14,.065),"SV_DarkIron",.018,"Wheelhouse")
    return pane
# An actual hollow pilot house, with separate framing and panes.
box("SV_Cabin_Floor",(0,5.7,1.07),(4.16,3.7,.14),"SV_Interior",.025,"Wheelhouse")
for side in [-1,1]:
    x=side*2.1
    box("SV_Cabin_LowerSide",(x,5.7,1.5),(.12,3.7,.92),"SV_IvoryPaint",.035,"Wheelhouse")
    box("SV_Cabin_Header",(x,5.7,3.04),(.12,3.7,.24),"SV_IvoryPaint",.02,"Wheelhouse")
    for y in [3.9,5.1,6.3,7.5]:
        box("SV_Cabin_WindowPost",(x,y,2.43),(.13,.13,1.02),"SV_IvoryPaint",.018,"Wheelhouse")
    for y in [4.5,5.7,6.9]:window("SV_Cabin_SideGlass",(x+side*.01,y,2.45),1.0,.85,"X")
    tube("SV_Cabin_Handrail",[(x+side*.14,4.1,1.62),(x+side*.14,7.3,1.62)],.025,"SV_Galvanized",10,"Wheelhouse")
for y in [3.9,7.5]:
    box("SV_Cabin_LowerWall",(0,y,1.5),(4.2,.12,.92),"SV_IvoryPaint",.025,"Wheelhouse")
    box("SV_Cabin_WindowHeader",(0,y,3.04),(4.2,.12,.24),"SV_IvoryPaint",.025,"Wheelhouse")
    for x in [-2.05,-.69,.69,2.05]:
        box("SV_Cabin_WindowPost",(x,y,2.45),(.13,.13,1.03),"SV_IvoryPaint",.018,"Wheelhouse")
    for x in [-1.37,0,1.37]:window("SV_Cabin_EndGlass",(x,y,2.45),1.13,.85)
# Weatherproof door and fittings on port side.
box("SV_Cabin_Door",(-2.18,4.55,1.96),(.065,.91,1.75),"SV_BluePaint",.03,"Wheelhouse")
window("SV_Door_Glass",(-2.22,4.55,2.42),.55,.59,"X")
for y in [4.2,4.9]:
    for z in [1.3,2.6]:
        cylinder("SV_Door_Hinge",(-2.23,y,z-.09),(-2.23,y,z+.09),.033,"SV_Galvanized",12,"Wheelhouse")
tube("SV_Door_Handle",[(-2.27,4.8,1.83),(-2.35,4.8,1.83),(-2.35,4.6,1.83),(-2.27,4.6,1.83)],.022,"SV_Galvanized",10,"Wheelhouse")
for x in [-1.37,0,1.37]:
    cylinder("SV_Wiper_Pivot",(x,3.81,2.03),(x,3.76,2.03),.045,"SV_DarkIron",16,"Wheelhouse")
    tube("SV_Windscreen_Wiper",[(x,3.76,2.03),(x+.2,3.76,2.5),(x+.37,3.76,2.67)],.015,"SV_Rubber",8,"Wheelhouse")
roof=box("SV_Cabin_Roof",(0,5.7,3.24),(4.75,4.26,.22),"SV_BluePaint",.085,"Wheelhouse")
for x in [-2.27,2.27]:
    tube("SV_Roof_Gutter",[(x,3.65,3.16),(x,7.7,3.16)],.048,"SV_DarkIron",10,"Wheelhouse")
for y in [3.65,7.72]:
    tube("SV_Roof_Gutter",[(-2.27,y,3.16),(2.27,y,3.16)],.045,"SV_DarkIron",10,"Wheelhouse")
# Navigation console, chair, dashboard and gauges, visible through the glazing.
console=box("SV_Console",(0,6.85,1.7),(2.45,.65,.95),"SV_Interior",.08,"Equipment")
dashboard=box("SV_Dashboard",(0,6.72,2.18),(2.4,.7,.12),"SV_DarkIron",.035,"Equipment")
dashboard.rotation_euler.x=math.radians(15)
for x in [-.75,-.3,.3,.75]:
    cylinder("SV_Gauge", (x,6.56,2.23),(x,6.56,2.27),.115,"SV_Galvanized",24)
    cylinder("SV_Gauge_Face",(x,6.56,2.272),(x,6.56,2.278),.095,"SV_Interior",24)
    cylinder("SV_Gauge_Needle",(x-.045,6.54,2.283),(x+.06,6.59,2.283),.008,"SV_Lettering",6)
for x in [-.95,-.63,-.31,0,.31,.63,.95]:
    cylinder("SV_Dashboard_Button",(x,6.85,2.25),(x,6.85,2.29),.026,"SV_RedLamp" if x<0 else "SV_DarkIron",12)
box("SV_Chart_Table",(-1.2,5.8,1.65),(1,.8,.12),"SV_WeatheredDeck",.03)
box("SV_Chart",(-1.2,5.8,1.72),(.8,.65,.012),"SV_Lettering",0)
cylinder("SV_Chair_Pedestal",(.6,5.7,1.12),(.6,5.7,1.68),.08,"SV_DarkIron",16)
box("SV_Helm_Seat",(.6,5.7,1.68),(.66,.65,.16),"SV_Rubber",.07)
box("SV_Helm_Backrest",(.6,5.43,2.02),(.66,.12,.65),"SV_Rubber",.055)
# A separate exterior working helm at the existing gameplay station.
cylinder("SV_Aft_Helm_Pedestal",(0,3.25,1),(0,3.25,1.7),.12,"SV_BluePaint",24)
box("SV_Aft_Control_Box",(0,3.31,1.57),(.7,.35,.38),"SV_IvoryPaint",.05)
torus("SV_Helm_Wheel",(0,3.08,1.9),.31,.026,"SV_WeatheredDeck",(math.pi/2,0,0))
cylinder("SV_Helm_Hub",(0,3.16,1.9),(0,3.01,1.9),.065,"SV_Brass",20)
for i in range(8):
    a=i*math.tau/8
    cylinder("SV_Wheel_Spoke",(0,3.08,1.9),(math.cos(a)*.32,3.08,1.9+math.sin(a)*.32),.014,"SV_Galvanized",8)
    cylinder("SV_Wheel_Handle",(math.cos(a)*.29,3.08,1.9+math.sin(a)*.29),(math.cos(a)*.42,3.08,1.9+math.sin(a)*.42),.026,"SV_WeatheredDeck",12)
# Mast, radar, loudhailer, exhaust, vents and navigation lamps.
cylinder("SV_Exhaust",(0,6,3.34),(0,6,4.65),.23,"SV_DarkIron",32)
torus("SV_Exhaust_Collar",(0,6,3.42),.27,.045,"SV_Galvanized")
cylinder("SV_Exhaust_Cowl",(0,6,4.63),(0,6,4.78),.34,"SV_DarkIron",32)
cylinder("SV_Main_Mast",(0,3.85,3.36),(0,3.85,8.2),.065,"SV_Galvanized",20,"Rigging")
cylinder("SV_Mast_Crossbar",(-1.65,3.85,6.8),(1.65,3.85,6.8),.04,"SV_Galvanized",16,"Rigging")
box("SV_Radar_Base",(0,4.55,3.55),(.5,.5,.4),"SV_IvoryPaint",.08,"Rigging")
box("SV_Radar_Array",(0,4.55,3.85),(2.15,.27,.18),"SV_IvoryPaint",.055,"Rigging")
for x in [-1.7,1.7]:
    cylinder("SV_Aerial",(x,7,3.3),(x,7,5.5),.015,"SV_DarkIron",10,"Rigging")
for x,mat in [(-2.16,"SV_RedLamp"),(2.16,"SV_GreenLamp")]:
    box("SV_Navigation_Lamp_Base",(x,4.15,3.37),(.35,.45,.12),"SV_DarkIron",.025,"Rigging")
    cylinder("SV_Navigation_Lamp",(x,4.15,3.43),(x,4.15,3.65),.11,mat,24,"Rigging")
for y in [4.5,7]:
    cylinder("SV_Mushroom_Vent",(.7,y,3.35),(.7,y,3.65),.14,"SV_Galvanized",24)
    cylinder("SV_Mushroom_Cap",(.7,y,3.65),(.7,y,3.72),.27,"SV_IvoryPaint",24)
for x in [-1.65,1.65]:
    tube("SV_Mast_Stay",[(x,7.2,3.36),(0,3.85,7.5)],.012,"SV_DarkIron",6,"Rigging")
def lettering(name,text,at,size,rotation=(math.pi/2,0,0),mat="SV_Lettering"):
    data=bpy.data.curves.new(name,"FONT");data.body=text;data.align_x="CENTER";data.size=size;data.extrude=.0015;data.bevel_depth=.0006
    try:data.font=bpy.data.fonts.load(r"C:\Windows\Fonts\arialbd.ttf")
    except RuntimeError:pass
    obj=bpy.data.objects.new(name,data);COL.objects.link(obj);obj.parent=ROOT
    obj.location=at;obj.rotation_euler=rotation;obj["assembly"]="Equipment"
    data.materials.append(M[mat])
    return obj
box("SV_Nameplate",(0,3.804,3.02),(3.45,.045,.34),"SV_DarkIron",.025)
lettering("SV_Vessel_Name","СЕВЕРНЫЙ",(0,3.775,2.925),.255)
lettering("SV_Stern_Name","СЕВЕРНЫЙ",(0,-7.82,.49),.32)
lettering("SV_Stern_Port","ПОРТ ПРИПИСКИ · СЕВЕРНЫЙ",(0,-7.826,.27),.09)
bpy.app.driver_namespace["SV_BUILD"].update(globals())
print("WHEELHOUSE_OK",len(COL.objects),"objects; detailed hollow cabin and exterior helm")
