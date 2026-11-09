"""Build the four playable interiors in an isolated Blender MCP session."""
import bpy
import math
from collections import defaultdict
from pathlib import Path
from mathutils import Vector

ROOT = Path(r"C:/Users/Redmi/Documents/Codex/2026-09-28/x20/outputs/lighthouse-keeper")

def material(name, color, metal=0, rough=.8, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    for channel, value in (("Base Color",(*color,1)),("Metallic",metal),("Roughness",rough),
                           ("Emission Color",(*color,1)),("Emission Strength",emission)):
        bsdf.inputs[channel].default_value = value
    return mat

def palette():
    return {
        "oak": material("Сырая древесина",(.19,.117,.067)),
        "honey": material("Строганая доска",(.32,.205,.102)),
        "dark": material("Смолёное дерево",(.10,.066,.044)),
        "wall": material("Серая вагонка",(.255,.249,.198)),
        "stone": material("Сланец",(.155,.177,.171)),
        "iron": material("Литое железо",(.072,.095,.099),.35),
        "steel": material("Потёртая оцинковка",(.255,.292,.28),.36),
        "blue": material("Серо-синяя эмаль",(.102,.21,.235),.23),
        "green": material("Морская зелень",(.12,.235,.195),.20),
        "red": material("Сурик",(.36,.10,.066),.14),
        "brass": material("Тёмная латунь",(.46,.29,.11),.55),
        "linen": material("Льняная ткань",(.41,.373,.29)),
        "cloth": material("Войлочное одеяло",(.193,.245,.163)),
        "paper": material("Старая бумага",(.55,.473,.319)),
        "line": material("Чернила",(.079,.106,.095)),
        "glass": material("Холодное матовое стекло",(.18,.31,.36),.1,.36,.19),
        "amber": material("Свет лампы",(.9,.47,.14),.1,.34,1.5),
        "signal": material("Рабочий индикатор",(.13,.65,.30),0,.45,1.2),
    }

def position(x,y,z):
    return (x,-z,y)

def part(mat, vertices, faces, group):
    verts, polys = groups[group][mat]
    base = len(verts)
    verts.extend(vertices)
    polys.extend(tuple(base+i for i in f) for f in faces)

def box(name, mat, at, size, group="Furniture", yaw=0):
    x,y,z = at
    dx,dy,dz = (v/2 for v in size)
    c,s = math.cos(yaw),math.sin(yaw)
    pts = [position(x+i*c+j*s,y+k,z-i*s+j*c) for k in (-dy,dy)
           for i,j in ((-dx,-dz),(dx,-dz),(dx,dz),(-dx,dz))]
    part(mat,pts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],group)

def pipe(mat, start, end, radius, group="Furniture", sides=12):
    a,b = Vector(position(*start)),Vector(position(*end))
    axis = (b-a).normalized()
    u = axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))).normalized()
    v = axis.cross(u)
    points = [base+radius*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))
              for base in (a,b) for i in range(sides)]
    faces = [tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
    faces += [(i,(i+1)%sides,sides+(i+1)%sides,sides+i) for i in range(sides)]
    part(mat,points,faces,group)

def marker(name, at, size=None):
    obj = bpy.data.objects.new(name,None)
    layout.objects.link(obj)
    obj.location = position(*at)
    obj.empty_display_type = "CUBE" if size else "PLAIN_AXES"
    if size:
        obj.scale = (size[0],size[2],size[1])
        obj.empty_display_size = .5

def solid(name, at, size):
    marker("COL_"+name,at,size)

def station(name, x, z):
    marker("ACT_"+name,(x,0,z))

def floor(w,d,mat,metal=False):
    n = 12 if metal else 19
    step = w/n
    for i in range(n):
        x = -w/2+step*(i+.5)
        m = mat if i%5 else ("steel" if metal else "oak")
        box("Floor plank",m,(x,-.065,0),(step-.012,.13,d),"Floor")
        if metal and i%2==0:
            for z in (-d*.43, d*.43):
                box("Fastener","iron",(x,.006,z),(.035,.014,.032),"Floor")
    solid("Floor",(0,-.09,0),(w,.18,d))

def wall(w,d,h,mat,side,opening=None):
    along_x = side in ("North","South")
    length = w if along_x else d
    edge = (-1 if side in ("North","West") else 1)*(d if along_x else w)/2
    group = "Wall_"+side
    def panel(along, y, span, height, style=mat, thick=.14):
        at = (along,y,edge) if along_x else (edge,y,along)
        size = (span,height,thick) if along_x else (thick,height,span)
        box("Wall",style,at,size,group)
    segments = [(-length/2,length/2)]
    if opening:
        x,width = opening
        segments = [(-length/2,x-width/2),(x+width/2,length/2)]
        panel(x,(h+2.04)/2,width,h-2.04)
        for j in (-1,1):
            panel(x+j*(width/2+.032),1.04,.067,2.08,"steel" if mat in ("blue","green") else "dark",.21)
        panel(x,2.08,width+.17,.09,"steel" if mat in ("blue","green") else "dark",.21)
    for a,b in segments:
        if mat in ("wall","oak"):
            count = max(1,math.ceil((b-a)/.30))
            for i in range(count):
                step = (b-a)/count
                panel(a+(i+.5)*step,h/2,step-.008,h,"oak" if i%7==0 else mat)
        else:
            panel((a+b)/2,h/2,b-a,h)
        panel((a+b)/2,.13,b-a,.22,"dark" if mat in ("wall","oak") else "iron",.19)
        panel((a+b)/2,h-.10,b-a,.12,"dark" if mat in ("wall","oak") else "steel",.19)
    # The room is a bounded gameplay cell, with E at the threshold.
    at = (0,h/2,edge) if along_x else (edge,h/2,0)
    solid(side,at,(length,h,.14) if along_x else (.14,h,length))

def window(x,y,z,width,height,group="Wall_North"):
    box("Frosted glass","glass",(x,y,z),(width,height,.05),group)
    for a in (-width/2,width/2,0):
        box("Frame","dark",(x+a,y,z+.03),(.063,height+.09,.09),group)
    for a in (-height/2,height/2):
        box("Frame","dark",(x,y+a,z+.03),(width+.1,.062,.10),group)

def lamp(x,y,z,group="Furniture"):
    pipe("iron",(x,y-.15,z),(x,y-.10,z),.12,group)
    pipe("amber",(x,y-.10,z),(x,y+.10,z),.085,group)
    pipe("iron",(x,y+.10,z),(x,y+.16,z),.13,group)
    pipe("iron",(x,y+.16,z),(x,y+.24,z-.13),.022,group)

def table(name,x,z,w,d,y=.87,mat="oak"):
    box("Worktop",mat,(x,y,z),(w,.10,d))
    for dx in (-w*.42,w*.42):
        for dz in (-d*.38,d*.38):
            box("Leg","dark",(x+dx,y/2,z+dz),(.074,y,.074))
    solid(name,(x,y/2,z),(w,y+.1,d))

def bed(name,x,z,w,d,metal=False):
    frame = "blue" if metal else "dark"
    box("Bed frame",frame,(x,.33,z),(w,.17,d))
    box("Mattress","linen",(x,.47,z),(w-.06,.15,d-.09))
    box("Wool blanket","cloth",(x,.56,z+d*.17),(w-.10,.06,d*.60))
    for shift in (-.30,.29):
        box("Woven stripe","linen",(x+w*shift,.596,z+d*.17),(.026,.012,d*.59))
    box("Pillow","linen",(x,.592,z-d*.32),(w*.71,.10,.36))
    for shift in (-.46,.46):
        for dx in (-w*.42,w*.42):
            box("Bed post",frame,(x+dx,.29,z+shift*d),(.08,.58,.08))
    solid(name,(x,.29,z),(w,.58,d))

def crate(mat,x,y,z,w=.55,d=.44,h=.36,group="Furniture"):
    box("Crate",mat,(x,y+h/2,z),(w,h,d),group)
    for dx in (-w*.41,w*.41):
        box("Crate batten","dark",(x+dx,y+h/2,z+d/2+.012),(.057,h,.030),group)
    box("Label","paper",(x,y+h*.56,z+d/2+.018),(w*.38,h*.21,.014),group)

def equipment(x,y,z,w=.76,h=.32,group="Furniture"):
    box("Receiver housing","iron",(x,y+h/2,z),(w,h,.37),group)
    box("Faceplate","steel",(x,y+h/2,z+.194),(w-.06,h-.055,.029),group)
    box("Dial window","glass",(x-w*.19,y+h*.64,z+.214),(w*.41,h*.29,.016),group)
    for i in range(6):
        box("Dial markings","line",(x-w*.35+i*w*.06,y+h*.66,z+.224),(.008,.032,.007),group)
    for dx in (.12,.30):
        pipe("iron",(x+w*dx,y+h*.44,z+.205),(x+w*dx,y+h*.44,z+.247),.047,group)
    for dx in (-.44,.44):
        pipe("brass",(x+w*dx,y+h*.8,z+.202),(x+w*dx,y+h*.8,z+.224),.014,group,8)

def chart(x,y,z,w,h,group):
    box("Chart board","dark",(x,y,z),(w+.09,h+.09,.038),group)
    box("Chart paper","paper",(x,y,z+.024),(w,h,.013),group)
    for dx in (-.33,-.16,0,.16,.33):
        box("Grid","linen",(x+w*dx,y,z+.032),(.008,h*.88,.007),group)
    for dy in (-.31,0,.31):
        box("Grid","linen",(x,y+h*dy,z+.032),(w*.91,.008,.007),group)
    coast = [(-.38,-.25),(-.23,-.12),(-.24,.10),(-.08,.25),(.08,.14),(.16,.23),(.29,.10),(.37,-.16)]
    for (a,b),(c,d) in zip(coast,coast[1:]):
        pipe("green",(x+a*w,y+b*h,z+.036),(x+c*w,y+d*h,z+.036),.014,group,6)
    box("Light symbol","red",(x+w*.08,y+h*.14,z+.039),(.05,.05,.011),group)

def keeper():
    floor(6.15,4.55,"honey")
    for side in ("North","West","South","East"):
        wall(6.15,4.55,2.6,"wall",side,(0,1.0) if side=="South" else None)
    window(-1.87,1.84,-2.187,1.03,.71)
    chart(.54,1.77,-2.17,1.15,.74,"Wall_North")
    bed("Bunk",-2.22,-1.02,1.1,1.95)
    crate("honey",-2.35,0,.50,.65,.52,.42)
    solid("Chest",(-2.35,.21,.50),(.65,.42,.52))
    table("RadioDesk",-.45,-1.69,1.28,.62)
    equipment(-.49,.93,-1.69,.67)
    box("Logbook","paper",(-.04,.935,-1.54),(.24,.036,.22),yaw=.14)
    lamp(-.99,1.68,-2.06,"Wall_North")
    x,z = 2.23,-1.50
    box("Hearth","stone",(x,.07,z),(1.18,.14,.92))
    box("Cast stove","iron",(x,.49,z),(.75,.76,.65))
    box("Fire door","steel",(x,.46,z+.339),(.43,.37,.055))
    box("Ember slit","red",(x,.52,z+.373),(.21,.065,.024))
    pipe("iron",(x+.17,.82,z-.14),(x+.17,2.58,z-.14),.108)
    pipe("iron",(x-.16,.87,z+.08),(x-.16,1.04,z+.08),.125)
    pipe("brass",(x-.16,1.04,z+.08),(x-.16,1.07,z+.08),.124)
    solid("Stove",(x,.46,z),(.82,.88,.74))
    table("WorkSurface",2.45,1.11,1.0,.71)
    for i in range(4):
        box("Mug","linen",(2.12+i*.18,.97,1.23),(.075,.11,.076))
    for i in range(9):
        box("Runner","cloth" if i%3 else "red",(0,.009,.24+i*.151),(.96,.018,.148),"Floor")
    box("Door threshold","honey",(0,.021,2.10),(1.04,.042,.15),"Floor")
    station("shelter",-1.40,-.74)
    station("radio",-.50,-1.00)
    station("cook",1.56,-1.12)

def transmitter():
    floor(5.0,3.88,"steel",True)
    for side in ("North","West","South","East"):
        wall(5.0,3.88,2.48,"green",side,(1.43,.93) if side=="South" else None)
    window(1.30,1.80,-1.84,.91,.60)
    chart(-.82,1.95,-1.84,1.55,.59,"Wall_North")
    table("SignalDesk",-.10,-1.41,2.66,.76,.94,"steel")
    equipment(-.98,1.0,-1.43,.84,.42)
    equipment(-.02,1.0,-1.46,.91,.57)
    equipment(.86,1.0,-1.44,.61,.26)
    lamp(-1.82,1.77,-1.70,"Wall_North")
    for i in range(3):
        z=-.38+i*.67
        crate("blue",-2.00,0,z,.72,.59,.40)
        crate("iron",-2.00,.40,z,.69,.58,.35)
    solid("EquipmentRack",(-2.0,.375,.29),(.72,.75,1.93))
    box("Battery cradle","iron",(-1.10,1.035,-1.10),(.47,.072,.32))
    box("Status fault","red",(.18,1.49,-1.236),(.041,.039,.019),"SignalOff")
    box("Status online","signal",(.18,1.49,-1.235),(.041,.039,.020),"SignalOn")
    crate("red",-1.10,1.08,-1.10,.42,.25,.21,"SignalOn")
    box("Threshold plate","brass",(1.43,.015,1.80),(.93,.03,.15),"Floor")
    station("transmitter",-.05,-.56)

def vessel():
    floor(4.7,4.60,"steel",True)
    for side in ("North","West","South","East"):
        wall(4.7,4.60,2.32,"blue",side,(1.21,.92) if side=="West" else None)
    for x in (-1.42,0,1.42):
        window(x,1.71,-2.20,1.19,.64)
    # The partition leaves a central walk-through between the bridge and the quarters.
    for x,w in ((-1.61,1.46),(1.64,1.42)):
        box("Bulkhead","blue",(x,1.29,.29),(w,1.90,.11),"BulkheadUpper")
        box("Cutaway bulkhead","blue",(x,.17,.29),(w,.34,.11),"BulkheadLow")
        box("Skirting","iron",(x,.09,.30),(w,.16,.15),"BulkheadLow")
        box("Section edge","steel",(x,.341,.29),(w,.023,.13),"BulkheadLow")
        solid("Partition"+str(x),(x,1.12,.29),(w,2.24,.11))
    table("HelmConsole",0,-1.76,3.15,.58,.90,"blue")
    for x in (-.86,-.47,.48,.86):
        pipe("iron",(x,.943,-1.62),(x,.974,-1.62),.108)
        pipe("glass",(x,.974,-1.62),(x,.984,-1.62),.077)
        box("Gauge needle","brass",(x+.012,.991,-1.62),(.044,.012,.016),yaw=.65)
    center=(0,1.19,-1.35)
    for i in range(24):
        a,b=i*math.tau/24,(i+1)*math.tau/24
        def rim(angle):
            return (math.cos(angle)*.30,1.19+math.sin(angle)*.30,-1.35)
        pipe("honey",rim(a),rim(b),.030,sides=8)
        if i%4==0:
            pipe("brass",center,rim(a),.017,sides=8)
    pipe("steel",(0,1.19,-1.77),(0,1.19,-1.34),.067)
    chart(1.51,1.47,-2.18,.52,.36,"Wall_North")
    for x in (-1.88,-.69,.69,1.88):
        for y in (.30,1.24,2.22):
            pipe("steel",(x,y,-2.218),(x,y,-2.193),.020,"Wall_North",8)
    box("Throttle plate","iron",(1.18,.963,-1.58),(.27,.024,.19))
    pipe("steel",(1.14,.972,-1.55),(1.14,1.14,-1.60),.023)
    pipe("red",(1.14,1.12,-1.593),(1.14,1.17,-1.606),.041)
    box("Sea log","paper",(-1.23,.963,-1.75),(.27,.026,.20),yaw=-.11)
    bed("SeaBerth",1.52,1.20,1.07,1.82,True)
    crate("blue",-1.32,0,1.84,.66,.48,.39)
    solid("SeaChest",(-1.32,.195,1.84),(.66,.39,.48))
    lamp(-1.97,1.84,-2.04,"Wall_North")
    lamp(1.43,1.64,.44,"BulkheadUpper")
    box("Door threshold","brass",(-2.22,.014,1.21),(.13,.028,.94),"Floor")
    station("ship_helm",0,-.97)

def storage():
    # This room is installed at the real warehouse on the island.
    for i in range(14):
        x=-3.87+.555*i
        box("Warehouse board","oak" if i%3 else "dark",(x,.009,0),(.542,.018,5.79),"Floor")
    for x in (-2.63,-1.22):
        for y in (.28,.96,1.62):
            box("Storage shelf","oak",(x,y,-2.38),(1.23,.08,.72))
            for j in (-1,1):
                crate("dark" if j>0 else "honey",x+j*.28,y+.043,-2.36,.48,.48,.25)
        for dx in (-.56,.56):
            for z in (-2.68,-2.07):
                box("Steel upright","iron",(x+dx,.91,z),(.055,1.82,.056))
        solid("Shelf"+str(x),(x,.91,-2.38),(1.23,1.82,.72))
    table("Workbench",2,-2.0,2.02,.90,.91)
    crate("red",2,.97,-2,.78,.42,.33,"ToolsPresent")
    pipe("iron",(1.31,1.014,-1.82),(1.58,1.014,-1.86),.029)
    pipe("brass",(2.59,1.02,-1.93),(2.72,1.02,-1.88),.029)
    for x,z in ((-3.10,.02),(-2.75,1.35)):
        crate("oak",x,0,z,.72,.65,.60)
        solid("Crate"+str(x),(x,.30,z),(.72,.60,.65))
    for y in (.12,.30,.48):
        for z in (-.25,.12,.50):
            box("Salvage stock","steel",(-1.62,y,z),(.80,.14,.12))
    solid("Salvage",(-1.62,.28,.12),(.82,.56,.90))
    box("Medical locker","steel",(3.62,.66,1.38),(.52,.98,.46))
    box("Medical door","linen",(3.62,.66,1.623),(.46,.87,.053))
    for h,w in ((.30,.077),(.073,.31)):
        box("Cross","red",(3.62,.75,1.656),(w,h,.014))
    for x in (3.45,3.79):
        box("Locker foot","iron",(x,.088,1.38),(.055,.18,.39))
    solid("MedicalLocker",(3.62,.58,1.38),(.52,1.16,.49))
    lamp(.52,2.06,-2.73)

def export(name, build):
    global groups, layout, mats
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for collection in list(bpy.context.scene.collection.children):
        if collection.name.startswith("Interior "):
            bpy.data.collections.remove(collection)
    bpy.data.orphans_purge(do_recursive=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    mats = palette()
    groups = defaultdict(lambda: defaultdict(lambda: ([], [])))
    layout = bpy.data.collections.new("Interior layout")
    scene.collection.children.link(layout)
    build()
    for group, submeshes in groups.items():
        vertices, faces, indices = [], [], []
        for i, (mat, (points, polys)) in enumerate(submeshes.items()):
            faces.extend(tuple(j+len(vertices) for j in face) for face in polys)
            vertices.extend(points)
            indices.extend([i]*len(polys))
        mesh = bpy.data.meshes.new(group)
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        obj = bpy.data.objects.new(group,mesh)
        scene.collection.objects.link(obj)
        for mat in submeshes:
            mesh.materials.append(mats[mat])
        for poly,index in zip(mesh.polygons,indices):
            poly.material_index = index
    bpy.ops.object.select_all(action='DESELECT')
    for obj in scene.objects:
        if obj.type=="MESH":
            obj.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["Floor"]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                area.spaces.active.region_3d.view_location=(0,0,1)
                area.spaces.active.region_3d.view_distance=11
                area.spaces.active.shading.color_type="MATERIAL"
    source = ROOT/"assets/source_blender/interiors"
    models = ROOT/"assets/models/interiors"
    source.mkdir(parents=True,exist_ok=True)
    models.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(name+".blend")))
    bpy.ops.export_scene.gltf(filepath=str(models/(name+".glb")),export_format="GLB",export_apply=True)
    print("ROOM",name,len(groups),len(layout.objects))

for name, build in (("keeper_cabin",keeper),("radio_outpost",transmitter),
                    ("vessel_wheelhouse",vessel),("warehouse",storage)):
    export(name,build)
