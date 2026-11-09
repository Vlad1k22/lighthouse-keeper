"""Build the lighthouse interior in Blender and export its cutaway groups."""
import bpy
import math
from collections import defaultdict
from pathlib import Path
from mathutils import Vector

ROOT = Path(r"C:/Users/Redmi/Documents/Codex/2026-09-28/x20/outputs/lighthouse-keeper")
PITCH, TURNS, STEPS = 3.24, 3, 24
TOP = PITCH * TURNS
INNER, OUTER, WALL = .54, 2.24, 2.38
LANDING = 2.2
TAU = math.tau

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.data.orphans_purge(do_recursive=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'

def material(name, rgb, metal=0, rough=.82, glow=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    for channel, value in {
        "Base Color": (*rgb, 1), "Metallic": metal, "Roughness": rough,
        "Emission Color": (*rgb, 1), "Emission Strength": glow,
    }.items():
        shader.inputs[channel].default_value = value
    return mat

stone = [material("Базальт %02d" % i, (v*.92, v, v*.95))
         for i, v in enumerate((.113, .138, .158, .185, .206))]
tread = [material("Ступени %02d" % i, (v, v*.96, v*.86))
         for i, v in enumerate((.18, .215, .24))]
mortar = material("Известковый шов", (.081, .091, .087))
iron = material("Воронёное железо", (.09, .112, .119), .45)
brass = material("Патинированная латунь", (.38, .233, .094), .55)
wood = material("Старая древесина", (.235, .146, .081))
wood_dark = material("Мокрые доски", (.132, .091, .059))
enamel = material("Серо-зелёная эмаль", (.12, .22, .195), .28)
red = material("Красный бак", (.33, .093, .056), .24)
rope = material("Просмолённый канат", (.35, .27, .16))
amber = material("Янтарное стекло ламп", (.83, .43, .11), .1, .32, 1.55)
glass = material("Зеленоватые призмы", (.30, .49, .43), .32, .28)
window = material("Сумерки за стёклами", (.075, .15, .167), .12, .4, .30)
meshes = defaultdict(lambda: defaultdict(lambda: ([], [])))

def part(group, mat, vertices, faces):
    verts, polys = meshes[group][mat]
    offset = len(verts)
    verts.extend(vertices)
    polys.extend(tuple(index+offset for index in face) for face in faces)

def polar(radius, angle, z):
    return (radius*math.cos(angle), -radius*math.sin(angle), z)

def wedge(group, mat, r1, r2, start, end, bottom, top):
    points = [polar(radius, angle, z) for z in (bottom, top)
              for radius, angle in ((r1, start), (r1, end), (r2, end), (r2, start))]
    part(group, mat, points, [(3,2,1,0), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)])

def ring(group, mat, r1, r2, start, end, bottom, top, pieces):
    for i in range(pieces):
        wedge(group, mat, r1, r2, start+(end-start)*i/pieces,
              start+(end-start)*(i+1)/pieces, bottom, top)

def bar(group, mat, start, end, width, depth=None, sides=8):
    a, b = Vector(start), Vector(end)
    axis = (b-a).normalized()
    u = axis.cross(Vector((0,0,1)) if abs(axis.z)<.95 else Vector((1,0,0))).normalized()
    v = axis.cross(u)
    verts = [base+u*(width/2*math.cos(t*TAU/sides))+v*((depth or width)/2*math.sin(t*TAU/sides))
             for base in (a,b) for t in range(sides)]
    faces = [tuple(reversed(range(sides))), tuple(range(sides, 2*sides))]
    faces += [(i, (i+1)%sides, sides+(i+1)%sides, sides+i) for i in range(sides)]
    part(group, mat, verts, faces)

def box(group, mat, center, size, angle=0):
    x, y, z = center
    dx, dy, dz = (v/2 for v in size)
    c, s = math.cos(angle), math.sin(angle)
    pts = [(x+i*c-j*s, y+i*s+j*c, z+k) for k in (-dz,dz)
           for i,j in ((-dx,-dy),(dx,-dy),(dx,dy),(-dx,dy))]
    part(group, mat, pts, [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

# Masonry arranged in camera-selectable sectors and vertical bands.
for level in range(4):
    for sector in range(16):
        group = f"Wall_{level:02d}_{sector:02d}"
        a, b = sector*TAU/16, (sector+1)*TAU/16
        base = PITCH*level
        if level == 3:
            ring(group, iron, WALL-.07, WALL+.1, a,b,base,base+.52,3)
            ring(group, iron, WALL-.07, WALL+.1, a,b,base+2.33,base+2.53,3)
            bar(group, iron, polar(WALL,a,base+.44),polar(WALL,a,base+2.5),.12,sides=6)
            bar(group, brass, polar(WALL,a,base+1.39),polar(WALL,b,base+1.39),.047,sides=6)
            wedge(group, window, WALL+.018, WALL+.034, a+.015,b-.015,base+.51,base+2.36)
            continue
        ring(group, mortar, WALL+.025, WALL+.25,a,b,base-.025,base+PITCH,4)
        for row in range(10):
            z = base + PITCH*row/10
            seam = (b-a)*(.35 if row%2 else .66)
            for column, (ca, cb) in enumerate(((a,a+seam),(a+seam,b))):
                wedge(group, stone[(sector*7+level*3+row*13+column*11)%len(stone)],
                      WALL+.009*((row*7+sector+column)%4),WALL+.21,
                      ca+.004,cb-.004,z+.013,z+PITCH/10-.012)
        ring(group, stone[1], WALL-.045,WALL+.26,a,b,base,base+.085,3)

ring("Foundation", mortar, .001, WALL+.06, 0,TAU,-.32,-.03,64)
for i in range(32):
    a, b = i*TAU/32,(i+1)*TAU/32
    wedge("Foundation", stone[(i*3)%5], .002,1.16,a+.004,b-.004,-.075,0)
    wedge("Foundation", stone[(i*7+2)%5], 1.17,WALL+.04,a+.003,b-.003,-.075,0)

for i in range(STEPS*TURNS):
    a, b = i*TAU/STEPS, (i+1)*TAU/STEPS
    bottom, top = i*PITCH/STEPS,(i+1)*PITCH/STEPS
    group = f"Flight_{i//2:02d}"
    wedge(group, tread[i%3], INNER, OUTER+.08, a,b, bottom-.16, (bottom+top)/2)
    bar(group, iron, polar(.57,a,bottom+1),polar(.57,b,top+1),.055)
    bar(group, iron, polar(.57,a,bottom+.58),polar(.57,b,top+.58),.027)
    if i%2==0:
        bar(group, iron, polar(.57,a,bottom),polar(.57,a,bottom+1.03),.07)
        bar(group, iron, (0,0,bottom-.04),(0,0,top+PITCH/STEPS+.04),.34,sides=12)
        bar(group, brass, (0,0,bottom+.03),(0,0,bottom+.10),.39,sides=12)
    if i%6==0:
        wedge(group, brass, 1.04,1.73,a+.012,a+.042,(bottom+top)/2,(bottom+top)/2+.009)

# Service bay, with all props against the wall and away from the stair entrance.
g = "ServiceBay"
for j in range(7):
    box(g,wood if j%3 else wood_dark,(1.81+j*.067,.96-j*.129,1.00),(.082,.14,1.93),-.47)
for z in (.16,1.72):
    bar(g, iron,(1.80,.99,z),(2.24,.15,z),.115)
for x,y in ((1.79,1.02),(2.24,.11)):
    for i in range(6):
        box(g,stone[(i+1)%5],(x,y,.18+i*.335),(.21,.20,.32),-.47)
bar(g,stone[1],(1.79,1.02,2.02),(2.24,.11,2.02),.23,sides=4)
bar(g, brass,(1.94,.56,1.03),(1.90,.49,1.03),.075)
box(g,brass,(1.88,.54,1.59),(.036,.24,.13),-.47)
box(g,wood_dark,(-.82,1.56,.83),(1.24,.43,.09),-.18)
box(g,wood,(-.82,1.56,.26),(1.24,.43,.065),-.18)
for x in (-1.34,-.33):
    for y in (1.40,1.72):
        box(g,iron,(x,y,.45),(.056,.056,.88))
for x,y,z,m in ((-1.19,1.55,.88,red),(-.89,1.58,.88,enamel),(-.61,1.62,.88,red),(-.54,1.5,.29,iron)):
    box(g,m,(x,y,z+.16),(.23,.18,.32))
    bar(g,brass,(x-.058,y,z+.33),(x+.058,y,z+.33),.03)
box(g,wood,(-1.33,.94,.23),(.5,.46,.46),.15)
for y in (.78,1.09):
    box(g,iron,(-1.33,y,.465),(.51,.046,.021),.15)
for t in range(58):
    a,b=t*.36,(t+1)*.36
    radius=.076+t*.0024
    a_pt=(-.96+radius*math.cos(a),.98+radius*math.sin(a),.035+t*.0009)
    b_pt=(-.96+(radius+.0024)*math.cos(b),.98+(radius+.0024)*math.sin(b),.035+(t+1)*.0009)
    bar(g,rope,a_pt,b_pt,.038,sides=6)
for z in (.12,.38,.64):
    box(g,wood,(-1.68,-.36,z),(.19,.55,.13),.17)
    box(g,brass,(-1.57,-.36,z),(.03,.42,.024),.17)

for i in range(9):
    level = PITCH*(i/3)
    a = 1.52+i*TAU/3
    group = f"Lamp_{i:02d}"
    base = polar(2.42,a,level+1.5)
    inset = polar(2.01,a,level+1.5)
    bar(group,iron,base,inset,.14)
    bar(group,iron,polar(2.01,a,level+1.34),polar(2.01,a,level+1.41),.21)
    bar(group,amber,polar(2.01,a,level+1.41),polar(2.01,a,level+1.62),.155)
    bar(group,iron,polar(2.01,a,level+1.62),polar(2.01,a,level+1.7),.21)

# Lantern room, with an open shaft over the final stair flight.
g = "LanternDeck"
ring(g,iron,.001,WALL+.03,0,LANDING,TOP-.15,TOP-.025,32)
for i in range(19):
    a,b=i*LANDING/19,(i+1)*LANDING/19
    wedge(g,tread[i%3],.003,WALL,a+.002,b-.002,TOP-.06,TOP)
    if i%3==0:
        wedge(g,brass,1.9,2.23,a+.01,a+.027,TOP,TOP+.008)
for r in (.59,1.03,1.48,1.93,2.32):
    bar(g,iron,polar(r,LANDING-.022,TOP),polar(r,LANDING-.022,TOP+1.06),.054)
for z in (.57,1.06):
    bar(g,iron,polar(.54,LANDING-.022,TOP+z),polar(WALL,LANDING-.022,TOP+z),.049)

g = "LanternOptic"
bar(g,iron,(0,0,TOP),(0,0,TOP+.17),1.04,sides=16)
bar(g,enamel,(0,0,TOP+.17),(0,0,TOP+.86),.79,sides=12)
for z,d in ((.22,.92),(.77,.87)):
    bar(g,brass,(0,0,TOP+z),(0,0,TOP+z+.06),d,sides=20)
for z,d in ((.88,1.07),(1.71,1.01),(1.76,.85)):
    bar("LensRotor",brass,(0,0,TOP+z),(0,0,TOP+z+.06),d,sides=20)
for i in range(4):
    a=TAU*i/4
    bar("LensRotor",brass,polar(.49,a,TOP+.89),polar(.49,a,TOP+1.77),.064)
for i in range(12):
    z = TOP+.95+i*.06
    radius = .38 + .10*math.sin(i*math.pi/11)
    ring("LensRotor",glass,radius-.035,radius,0,TAU,z,z+.04,24)
bar("BeaconGlow", amber,(0,0,TOP+1.03),(0,0,TOP+1.6),.36,sides=16)
box(g,enamel,(.05,-.83,TOP+.64),(.46,.36,1.26))
box(g,iron,(.05,-.83,TOP+1.29),(.53,.44,.08))
for x,m in ((-.09,enamel),(.05,red),(.19,brass)):
    bar(g,m,(x,-.84,TOP+1.31),(x,-.84,TOP+1.35),.065)
box("BeaconGlow",amber,(-.09,-.84,TOP+1.35),(.028,.028,.017))
for i in range(8):
    a = i*TAU/8
    bar(g,brass,polar(.40,a,TOP+.27),polar(.48,a,TOP+.27),.087)

for name, groups in meshes.items():
    vertices, faces, indices = [], [], []
    for material_index, (mat, (verts, polys)) in enumerate(groups.items()):
        faces.extend(tuple(i+len(vertices) for i in face) for face in polys)
        vertices.extend(verts)
        indices.extend([material_index]*len(polys))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    for mat in groups:
        mesh.materials.append(mat)
    for polygon, index in zip(mesh.polygons, indices):
        polygon.material_index = index

# Recalculate winding for all solids before exporting single-sided game materials.
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = bpy.data.objects["Foundation"]
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_location = (0,0,5.5)
            area.spaces.active.region_3d.view_distance = 16
            area.spaces.active.shading.color_type = "MATERIAL"

source = ROOT/"assets/source_blender/lighthouse/lighthouse_interior_v01.blend"
export = ROOT/"assets/models/lighthouse/lighthouse_interior_v01.glb"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(export), export_format="GLB", export_apply=True)
print(f"INTERIOR: {len(meshes)} groups, {export.stat().st_size} bytes")
