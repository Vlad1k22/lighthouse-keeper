import bpy
globals().update(bpy.app.driver_namespace["SV_BUILD"])
stations=[(-7.8,2.8),(-7.4,3.15),(-5.5,3.35),(-2,3.4),(2,3.4),(5.5,3.35),(7.6,2.55),(9,1.35),(9.8,.4),(10,.05)]
def width(y): return float(np.interp(y,[p[0] for p in stations],[p[1] for p in stations]))
def hull_point(y,t):
    w=width(y)
    sheer=1.045+max(0,y-5.5)*.045
    z=sheer-(sheer+.85)*math.sin(t)**.8
    x=-w*math.cos(t)*(1-.1*math.sin(t))
    return (x,y,z)
ys=np.linspace(-7.8,10,60)
ts=np.linspace(0,math.pi,30)
verts=[hull_point(float(y),float(t)) for y in ys for t in ts]
faces=[]
for j in range(len(ys)-1):
    for i in range(len(ts)-1):
        a=j*len(ts)+i
        faces.append((a,a+len(ts),a+len(ts)+1,a+1))
faces.append(tuple(reversed(range(len(ts)))))
faces.append(tuple(range((len(ys)-1)*len(ts),len(ys)*len(ts))))
hull=mesh("SV_Hull_Shell",verts,faces,"SV_BluePaint","Hull",lambda co:(co.y/4,co.z/3))
hull.data.materials.append(M["SV_Antifouling"])
for polygon in hull.data.polygons:
    polygon.use_smooth=True
    if sum(hull.data.vertices[v].co.z for v in polygon.vertices)/len(polygon.vertices)<-.04:polygon.material_index=1
solid=hull.modifiers.new("Steel plate thickness","SOLIDIFY")
solid.thickness=.032
bevel(hull,.012,2)
# A closed structural deck and individually bevelled, staggered timber planks.
outline=[(-width(float(y))*.98,float(y),.90) for y in ys]
outline += [(width(float(y))*.98,float(y),.90) for y in reversed(ys)]
deck=mesh("SV_Deck_Substrate",outline,[tuple(reversed(range(len(outline))))],"SV_DarkIron","Deck")
for ix in range(29):
    x=-3.22+ix*.23
    length_end=max([float(y) for y in ys if width(float(y))>abs(x)+.13],default=-7.8)
    length_start=min([float(y) for y in ys if width(float(y))>abs(x)+.13],default=-7.8)
    breaks=[length_start]
    cut=length_start+1+(ix%4)*.55
    while cut<length_end:
        breaks.append(cut);cut+=2.7
    breaks.append(length_end)
    for a,b in zip(breaks,breaks[1:]):
        if b-a<.08:continue
        segments=[(a,b)]
        if abs(x)<.96:
            segments=[(a,min(b,-1.85)),(max(a,-.15),b)]
        for aa,bb in segments:
            if bb-aa<.08:continue
            plank=box("SV_Deck_Plank",(x,(aa+bb)/2,.975),(.219,bb-aa-.018,.05),"SV_WeatheredDeck",.004,"Deck")
            uv=plank.data.uv_layers.active
            ox=rng.uniform(0,5);oy=rng.uniform(0,5)
            for poly in plank.data.polygons:
                for li in poly.loop_indices:
                    co=plank.data.vertices[plank.data.loops[li].vertex_index].co
                    uv.data[li].uv=(co.x*4+ox,co.y*.38+oy)
            for sy in [aa+.09,bb-.09]:
                if bb-aa>.25:bolt("SV_Deck_Fastener",(x,sy,1.003),.011,"Deck")
# Sheer strips and steel plate seams, following the curved hull.
for side,tbase in [(-1,0),(1,math.pi)]:
    for t in [.22,.53,.86]:
        pts=[hull_point(float(y),t if side<0 else math.pi-t) for y in ys]
        tube("SV_Hull_Plate_Seam",pts,.009,"SV_DarkIron",6,"Hull")
    pts=[(side*width(float(y))*1.003,float(y),.82+max(0,float(y)-5.5)*.045) for y in ys]
    tube("SV_Rubbing_Strake",pts,.055,"SV_Rubber",10,"Hull")
    for y in np.linspace(-7.1,8.8,27):
        w=width(float(y))
        for z in [.43,.74]:
            cylinder("SV_Hull_Rivet",(side*(w-.025),float(y),z),(side*(w+.016),float(y),z),.018,"SV_Galvanized",8,"Hull")
# Handrails leave a full 2.7 m gap at the starboard gangplank.
for side in [-1,1]:
    runs=[(-7.5,9.5)] if side<0 else [(-7.5,-4.35),(-1.55,9.5)]
    for ya,yb in runs:
        run_ys=np.linspace(ya,yb,max(3,int((yb-ya)/.5)))
        for h in [1.55,1.97]:
            tube("SV_Deck_Handrail",[(side*width(float(y))*.975,float(y),h+max(0,float(y)-6)*.05) for y in run_ys],.032,"SV_Galvanized",10,"Rails")
        for y in np.linspace(ya,yb,max(2,int((yb-ya)/1.25)+1)):
            x=side*width(float(y))*.975
            cylinder("SV_Rail_Post",(x,float(y),1.02),(x,float(y),1.97+max(0,float(y)-6)*.05),.035,"SV_Galvanized",12,"Rails")
            plate=box("SV_Rail_Foot",(x,float(y),1.015),(.14,.14,.03),"SV_DarkIron",.008,"Rails")
            bolt("SV_Rail_Foot_Bolt",(x+.04,float(y)+.035,1.04),.015,"Rails")
for h in [1.55,1.97]:
    tube("SV_Stern_Rail",[(-2.8,-7.65,h),(0,-7.65,h),(2.8,-7.65,h)],.034,"SV_Galvanized",10,"Rails")
# Thick edge capping, anchors and the keel.
for side in [-1,1]:
    tube("SV_Gunwale",[(side*width(float(y))*.98,float(y),1.065+max(0,float(y)-5.5)*.045) for y in ys if side<0 or not(-4.35<float(y)<-1.55)],.045,"SV_DarkIron",10,"Hull")
tube("SV_Keel",[(0,float(y),-.83) for y in ys[3:-3]],.075,"SV_DarkIron",10,"Hull")
# Deck access ramp is a separate component; the existing fixed ramp remains physical in Godot.
gang=box("SV_Gangplank_Frame",(4.65,-3,.86),(3,.0+2.05,.20),"SV_DarkIron",.02,"Gangplank")
for i in range(12):
    box("SV_Gangplank_Plank",(3.3+i*.25,-3,.979),(.238,1.98,.042),"SV_WeatheredDeck",.004,"Gangplank")
for y in [-4.02,-1.98]:
    tube("SV_Gangplank_Rope",[(3.25,y,1.78),(4.65,y,1.63),(6.15,y,1.78)],.026,"SV_Rope",8,"Gangplank")
    for x in [3.25,6.15]: cylinder("SV_Gangplank_Post",(x,y,1),(x,y,1.8),.03,"SV_Galvanized",12,"Gangplank")
bpy.app.driver_namespace["SV_BUILD"].update(globals())
print("HULL_OK",len(COL.objects),"source objects; deck z=1.000 m; starboard access gap retained")
