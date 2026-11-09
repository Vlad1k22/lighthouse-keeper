"""Blender MCP script: stylized, skinned characters and named in-place action clips."""
import bpy
import math
import os
from mathutils import Vector, Euler
from pathlib import Path

PROJECT = Path(os.environ.get("LIGHTHOUSE_PROJECT", r"C:/Users/Redmi/Documents/Codex/2026-09-28/x20/outputs/lighthouse-keeper"))
TAU = math.tau

def mat(name, color, rough=.82, metal=0., glow=0.):
    rgb = tuple(int(color[i:i+2],16)/255 for i in (0,2,4))
    rgb = tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in rgb)
    m = bpy.data.materials.new(name)
    m.diffuse_color=(*rgb,1)
    m.use_nodes=True
    n=m.node_tree.nodes.get('Principled BSDF')
    n.inputs['Base Color'].default_value=(*rgb,1)
    n.inputs['Roughness'].default_value=rough
    n.inputs['Metallic'].default_value=metal
    if glow:
        n.inputs['Emission Color'].default_value=(*rgb,1)
        n.inputs['Emission Strength'].default_value=glow
    return m

class Character:
    def __init__(self, kind):
        self.kind=kind
        self.hero=kind=='keeper'
        self.thin=kind=='shadow'
        self.heavy=kind=='drowned'
        self.width=1.18 if self.heavy else .84 if self.thin else 1.
        self.height=1.115 if self.thin else 1.025 if self.heavy else 1.
        self.parts=[]
        self.glow=[]
        self.bones={}
        self.rig=None
        main={'keeper':'a57c3c','shadow':'222f37','drowned':'4b5146'}[kind]
        trim={'keeper':'74552d','shadow':'19232b','drowned':'383d35'}[kind]
        self.coat=mat(kind+' waxed coat',main,.72)
        self.trim=mat(kind+' binding',trim,.86)
        self.patch=mat(kind+' canvas repair',{'keeper':'b48b4b','shadow':'34444c','drowned':'5e6452'}[kind],.89)
        self.pants=mat(kind+' trousers','393b38' if self.hero else '252d31',.9)
        self.boot=mat(kind+' rubber','303331' if self.hero else '242a2a',.67)
        self.sole=mat(kind+' worn sole','45413a' if self.hero else '383c38')
        self.metal=mat(kind+' oxidized iron','494945',.48,.45)
        self.leather=mat(kind+' leather','4b382b' if self.hero else '302e2a',.88)
        self.skin=mat(kind+' face','bf8e73' if self.hero else '090e13' if self.thin else '606960')
        self.dark=mat(kind+' recess','232827' if self.hero else '10151a')
        self.eye=mat(kind+' eye','313436' if self.hero else '829a9e' if self.thin else '606960',.78,0,.22 if self.thin else 0)
        self.vest=mat(kind+' faded flotation vest','784d41',.87)
        self.kelp=mat(kind+' kelp','626448',.62)
        self.amber=mat(kind+' oil light','ffd384',.27,0,1.65)

    def p(self, xyz):
        x,y,z=xyz
        return Vector((x*self.width,y,z*self.height))

    def local(self, xyz):
        x,y,z=xyz
        return Vector((x/self.width,y,z/self.height))

    def bone(self, name, head, tail, parent=None):
        self.bones[name]=(self.p(head),self.p(tail),parent)

    def make_rig(self):
        self.bone('Root',(0,0,0),(0,0,.22))
        self.bone('Pelvis',(0,0,.90),(0,0,1.09),'Root')
        self.bone('Spine',(0,0,1.09),(0,-.014,1.36),'Pelvis')
        self.bone('Chest',(0,-.014,1.36),(0,-.025,1.55),'Spine')
        self.bone('Head',(0,-.025,1.55),(0,-.035,1.82),'Chest')
        for side,sgn in [('L',-1),('R',1)]:
            arm_x=.244 if self.heavy else .222
            elbow=(sgn*(arm_x+.126),-.002,1.188 if not self.thin else 1.155)
            wrist=(sgn*(arm_x+.232),-.036,.933 if not self.thin else .870)
            shoulder=(sgn*arm_x,-.02,1.448)
            self.bone('UpperArm.'+side,shoulder,elbow,'Chest')
            self.bone('Forearm.'+side,elbow,wrist,'UpperArm.'+side)
            self.bone('Hand.'+side,wrist,(wrist[0]+sgn*.02,-.046,wrist[2]-.114),'Forearm.'+side)
            hip=(sgn*.118,0,.89)
            knee=(sgn*.128,-.02,.49)
            ankle=(sgn*.139,.012,.143)
            self.bone('Thigh.'+side,hip,knee,'Pelvis')
            self.bone('Shin.'+side,knee,ankle,'Thigh.'+side)
            self.bone('Foot.'+side,ankle,(ankle[0],-.16,.055),'Shin.'+side)
        if self.hero:
            w=self.bones['Hand.R'][0]
            l=tuple(w+Vector((.009,-.029,-.225)))
            self.bone('Lantern',l,(l[0],l[1],l[2]+.14),'Hand.R')
        arm=bpy.data.armatures.new(self.kind.title()+' Skeleton')
        self.rig=bpy.data.objects.new('Rig',arm)
        bpy.context.collection.objects.link(self.rig)
        bpy.context.view_layer.objects.active=self.rig
        self.rig.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        for name,(head,tail,parent) in self.bones.items():
            b=arm.edit_bones.new(name);b.head=head;b.tail=tail
            if parent:b.parent=arm.edit_bones[parent]
        bpy.ops.object.mode_set(mode='OBJECT')
        self.rig.show_in_front=True
        self.rig.data.display_type='STICK'

    def skin_obj(self,o,name,m,weights,light=False):
        o.name=name
        o.data.materials.append(m)
        if isinstance(weights,str):
            o.vertex_groups.new(name=weights).add(list(range(len(o.data.vertices))),1,'REPLACE')
        else:
            groups={}
            for vi,entries in enumerate(weights):
                for bn,w in entries:
                    if w<=0:continue
                    if bn not in groups:groups[bn]=o.vertex_groups.new(name=bn)
                    groups[bn].add([vi],w,'REPLACE')
        (self.glow if light else self.parts).append(o)
        return o

    def loft(self,name,rows,m,weights,segments=12,ragged=False):
        vs=[];faces=[];vw=[]
        for j,(cx,cy,z,rx,ry) in enumerate(rows):
            for i in range(segments):
                a=TAU*i/segments
                wobble=1+.024*math.sin(5*a+j*.8)+.017*math.cos(3*a-j*.9)
                zz=z+(.017*math.sin(i*5.7)+.012*math.cos(i*2.7) if ragged and j==0 else 0)
                vs.append(self.p((cx+rx*math.cos(a)*wobble,cy+ry*math.sin(a)*wobble,zz)))
                vw.append(weights(j,a) if callable(weights) else [(weights,1)])
        faces.append(tuple(reversed(range(segments))))
        for j in range(len(rows)-1):
            for i in range(segments):
                k=j*segments+i; n=j*segments+(i+1)%segments
                faces.append((k,n,n+segments,k+segments))
        faces.append(tuple(range((len(rows)-1)*segments,len(rows)*segments)))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],faces);mesh.update()
        o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
        for f in mesh.polygons:f.use_smooth=(len(f.vertices)==4)
        return self.skin_obj(o,name,m,vw)

    def sphere(self,name,at,sz,m,bone,sub=2):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=self.p(at))
        o=bpy.context.object
        o.scale=self.p(sz)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        return self.skin_obj(o,name,m,bone)

    def box(self,name,at,sz,m,bone,bevel=.013,rot=None):
        bpy.ops.mesh.primitive_cube_add(size=1,location=self.p(at))
        o=bpy.context.object;o.dimensions=self.p(sz)
        if rot:o.rotation_euler=rot
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if bevel:
            b=o.modifiers.new('Rounded sewn edges','BEVEL');b.width=bevel;b.segments=2
            bpy.ops.object.modifier_apply(modifier=b.name)
        return self.skin_obj(o,name,m,bone)

    def tube(self,name,points,radii,m,bones,segments=10, light=False):
        # Continuous cross-sections across elbow/knee with a smooth skin blend.
        pts=[self.p(p) for p in points]
        vs=[];faces=[];weights=[]
        for j,(at,r) in enumerate(zip(pts,radii)):
            d=(pts[min(j+1,len(pts)-1)]-pts[max(j-1,0)]).normalized()
            a=Vector((0,1,0)).cross(d).normalized()
            if a.length<.1:a=Vector((1,0,0))
            b=d.cross(a).normalized()
            for i in range(segments):
                q=TAU*i/segments
                rr=r*(1+.035*math.cos(q*3+j))
                vs.append(at+rr*(a*math.cos(q)+b*math.sin(q)))
                weights.append([(bones,1)] if isinstance(bones,str) else bones[j])
        faces.append(tuple(reversed(range(segments))))
        for j in range(len(pts)-1):
            for i in range(segments):
                k=j*segments+i;n=j*segments+(i+1)%segments
                faces.append((k,n,n+segments,k+segments))
        faces.append(tuple(range((len(pts)-1)*segments,len(pts)*segments)))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],faces);mesh.update()
        o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
        for f in mesh.polygons:f.use_smooth=len(f.vertices)==4
        return self.skin_obj(o,name,m,weights,light)

    def line(self,name,pts,r,m,bone):
        return self.tube(name,pts,[r]*len(pts),m,bone,8)

    def mesh(self):
        hem=.61 if self.thin else .755 if self.hero else .792
        def coat_weight(j,a):
            if j==0:return [('Pelvis',.48),('Thigh.L' if math.cos(a)<0 else 'Thigh.R',.52)]
            if j<3:return [('Pelvis',1)]
            if j==3:return [('Pelvis',.3),('Spine',.7)]
            return [('Chest',1)] if j>4 else [('Spine',.4),('Chest',.6)]
        self.loft('Shaped storm coat',[(0,.004,hem,.254,.165),(0,.012,hem+.048,.245,.158),(0,.009,.94,.205,.139),(0,.008,1.07,.193,.13),(0,-.001,1.22,.211,.139),(0,-.014,1.389,.247,.151),(0,-.023,1.467,.222,.133),(0,-.029,1.522,.124,.107)],self.coat,coat_weight,16,self.thin)
        self.loft('High collar',[(0,-.026,1.487,.137,.112),(0,-.034,1.553,.122,.103),(0,-.033,1.582,.115,.101)],self.trim,'Chest',14)
        for j,z in enumerate((.91,1.041,1.173,1.302,1.415)):
            b='Pelvis' if j<2 else 'Spine' if j==2 else 'Chest'
            self.sphere('Storm flap button',(-.014,-(.162 if j in (0,4) else .143),z),(.016,.010,.016),self.metal,b,1)
        self.line('Chest placket',[(.025,-.147,1.183),(.025,-.169,1.36),(.025,-.15,1.46)],.009,self.trim,'Chest')
        for s,sgn in [('L',-1),('R',1)]:
            upper,fore,hand='UpperArm.'+s,'Forearm.'+s,'Hand.'+s
            shoulder,elbow=(self.local(v) for v in self.bones[upper][:2])
            wrist=self.local(self.bones[hand][0])
            pts=[shoulder+Vector((-.02*sgn,0,.025)),shoulder.lerp(elbow,.27),shoulder.lerp(elbow,.8),elbow,elbow.lerp(wrist,.25),elbow.lerp(wrist,.78),wrist]
            factor=1.20 if self.heavy else .79 if self.thin else 1
            self.tube('Jointed sleeve '+s,pts,[r*factor for r in [.092,.096,.068,.068,.061,.051,.054]],self.coat,
                [[(upper,1)],[(upper,1)],[(upper,.90),(fore,.10)],[(upper,.48),(fore,.52)],[(upper,.12),(fore,.88)],[(fore,1)],[(fore,1)]],12)
            self.tube('Storm cuff '+s,[elbow.lerp(wrist,.83),wrist],[.055*factor,.055*factor],self.trim,fore,12)
            hand_len=.148 if self.thin else .118
            self.sphere('Hand '+s,wrist+Vector((sgn*.013,-.003,-hand_len*.43)),(.042*factor,.032*factor,hand_len*.56),self.skin if not self.hero else self.boot,hand)
            self.sphere('Thumb '+s,wrist+Vector((-sgn*.023,-.031,-.05)),(.016,.022,.032),self.skin if not self.hero else self.boot,hand)
            thigh,shin,foot='Thigh.'+s,'Shin.'+s,'Foot.'+s
            x=sgn*.126
            self.loft('Jointed trouser '+s,[(x,.012,.158,.063,.065),(x,.01,.313,.076,.075),(x,-.015,.444,.086,.081),(x,-.022,.495,.085,.083),(x,-.005,.572,.094,.091),(x,0,.73,.108,.097),(sgn*.118,0,.92,.107,.102)],self.pants,
                lambda j,a:[(shin,1)] if j<2 else [(shin,.72),(thigh,.28)] if j==2 else [(shin,.48),(thigh,.52)] if j==3 else [(thigh,1)],12)
            self.loft('Boot shaft '+s,[(sgn*.139,.009,.094,.069,.077),(sgn*.139,.012,.159,.071,.081),(x,.008,.292,.084,.084),(x,.007,.313,.085,.085)],self.boot,shin,12)
            self.box('Rubber tread '+s,(sgn*.139,-.054,.038),(.158,.259,.076),self.sole,foot,.023)
            self.box('Deck boot '+s,(sgn*.139,-.056,.092),(.150,.246,.112),self.boot,foot,.034)
            self.box('Pocket '+s,(sgn*.12,-.145,hem+.13),(.119,.045,.154),self.patch,'Pelvis',.017)
            self.box('Pocket flap '+s,(sgn*.12,-.171,hem+.204),(.124,.023,.045),self.trim,'Pelvis',.009)
        if self.hero:
            self.keeper_head()
            self.loft('Stitched belt',[(0,.007,1.013,.207,.144),(0,.007,1.060,.205,.142)],self.leather,'Pelvis',16)
            self.box('Belt buckle',(.019,-.150,1.035),(.067,.03,.052),self.metal,'Pelvis',.008)
            self.box('Leather tool pouch',(.175,-.118,1.00),(.138,.092,.159),self.leather,'Pelvis',.02,(0,0,-.33))
            self.sphere('Folded hood',(0,.112,1.432),(.149,.115,.113),self.trim,'Chest')
            self.lantern()
        else:
            self.hood()
            if self.heavy:self.flotation()

    def keeper_head(self):
        beard=mat('Keeper stubble','655047',.92)
        cap=mat('Keeper ribbed wool','323836',.93)
        self.loft('Stylized head',[(0,-.056,1.548,.048,.064),(0,-.062,1.574,.071,.077),(0,-.043,1.619,.096,.091),(0,-.039,1.679,.101,.090),(0,-.031,1.737,.100,.091),(0,-.020,1.785,.073,.072)],self.skin,'Head',12)
        self.sphere('Short beard',(0,-.084,1.593),(.072,.063,.042),beard,'Head')
        self.sphere('Nose',(0,-.134,1.655),(.024,.027,.033),self.skin,'Head',1)
        for sign in (-1,1):
            self.sphere('Ear',(sign*.095,-.024,1.65),(.023,.027,.036),self.skin,'Head',1)
            self.sphere('Eye',(sign*.039,-.124,1.688),(.021,.009,.010),self.eye,'Head',1)
            self.box('Brow',(sign*.040,-.125,1.706),(.046,.014,.011),beard,'Head',.004,(0,sign*.08,0))
        self.loft('Wool beanie',[(0,-.027,1.733,.111,.104),(0,-.019,1.766,.114,.107),(0,-.015,1.813,.105,.103),(0,-.01,1.859,.071,.075),(0,-.006,1.876,.032,.038)],cap,'Head',16)
        self.loft('Folded hat brim',[(0,-.027,1.734,.112,.105),(0,-.026,1.759,.118,.110),(0,-.023,1.775,.116,.107)],self.dark,'Head',16)
        for j in range(24):
            a=TAU*j/24
            self.line('Wool rib',[(.115*math.cos(a),-.025+.109*math.sin(a),1.742),(.118*math.cos(a),-.024+.112*math.sin(a),1.773),(.102*math.cos(a),-.014+.102*math.sin(a),1.817)],.0035,cap,'Head')

    def hood(self):
        # The dark inset under the brim is the face; the hood remains a solid readable silhouette.
        self.loft('Wet hood',[(0,-.023,1.489,.100,.096),(0,-.043,1.550,.135,.117),(0,-.051,1.659,.138,.119),(0,-.064,1.767,.104,.114),(0,-.041,1.847,.041,.071),(0,-.023,1.867,.014,.025)],self.coat,'Head',13)
        self.sphere('Deep hood opening',(0,-.147,1.668),(.104,.043,.130),self.dark,'Head',2)
        self.sphere('Blank face',(0,-.174,1.666),(.071 if self.heavy else .080,.025,.095),self.skin,'Head',2)
        self.line('Hood edge',[(-.091,-.155,1.572),(-.118,-.168,1.657),(-.095,-.176,1.743),(0,-.175,1.786),(.094,-.176,1.743),(.118,-.168,1.657),(.091,-.155,1.572)],.014,self.trim,'Head')
        if self.thin:
            for sign in (-1,1):self.sphere('Distant eye',(sign*.031,-.197,1.70),(.009,.006,.008),self.eye,'Head',1)

    def flotation(self):
        for sign in (-1,1):
            self.box('Flotation pad',(sign*.111,-.145,1.309),(.181,.107,.330),self.vest,'Chest',.046,(0,sign*.09,0))
            self.box('Lower flotation pad',(sign*.107,-.154,1.105),(.181,.101,.148),self.vest,'Spine',.03)
        self.box('Back flotation pad',(0,.119,1.315),(.379,.110,.33),self.vest,'Chest',.052)
        for z,b in ((1.145,'Spine'),(1.267,'Chest')):
            self.loft('Flotation webbing',[(0,.004,z-.015,.254,.199),(0,.004,z+.014,.253,.2)],self.leather,b,16)
            self.box('Vest buckle',(.008,-.205,z),(.072,.027,.052),self.metal,b,.009)
        for i in range(5):
            x=-.167+i*.021
            self.line('Kelp on shoulder',[(x,.018,1.49),(x-.024,-.10,1.457),(x-.035,-.151,1.40-i*.014),(x-.012,-.186,1.325-i*.011)],.014,self.kelp,'Chest')

    def lantern(self):
        x,y,z=self.bones['Lantern'][0]
        center=(x,y,z)
        self.loft('Lantern base',[(x,y,z-.11,.077,.077),(x,y,z-.077,.078,.078),(x,y,z-.06,.061,.061)],self.metal,'Lantern',16)
        self.loft('Lantern cap',[(x,y,z+.061,.057,.057),(x,y,z+.089,.065,.065),(x,y,z+.115,.048,.048)],self.metal,'Lantern',16)
        self.tube('Amber lantern glass',[(x,y,z-.065),(x,y,z-.042),(x,y,z+.039),(x,y,z+.065)],[.048,.056,.055,.045],self.amber,'Lantern',16,True)
        for side in (-1,1):
            self.line('Lantern guard',[(x+side*.055,y,z-.086),(x+side*.087,y,z-.045),(x+side*.084,y,z+.051),(x+side*.049,y,z+.10)],.012,self.metal,'Lantern')
        pts=[(x+.071*math.cos(a),y,z+.103+.10*math.sin(a)) for a in [i*math.pi/10 for i in range(11)]]
        self.line('Lantern carry handle',pts,.008,self.metal,'Lantern')

    def attach_skin(self):
        for parts,name in [(self.parts,'Body'),(self.glow,'LanternGlow')]:
            if not parts:continue
            bpy.ops.object.select_all(action='DESELECT')
            for o in parts:o.select_set(True)
            bpy.context.view_layer.objects.active=parts[0]
            bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
            if len(parts)>1:bpy.ops.object.join()
            o=bpy.context.object;o.name=name;o.data.name=self.kind+' '+name
            o.parent=self.rig
            m=o.modifiers.new('Character skin','ARMATURE');m.object=self.rig
            o.data.calc_loop_triangles()
        self.rig.select_set(True)

    def pose(self, frame, rotations, bounce=0):
        for b in self.rig.pose.bones:
            b.rotation_mode='QUATERNION'
            rest=b.bone.matrix_local.to_quaternion()
            value=Euler(rotations.get(b.name,(0,0,0)),'XYZ').to_quaternion()
            b.rotation_quaternion=rest.inverted()@value@rest
            b.location=rest.inverted()@Vector((0,0,bounce)) if b.name=='Pelvis' else Vector((0,0,0))
            b.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=b.name)
            if b.name=='Pelvis':b.keyframe_insert(data_path='location',frame=frame,group=b.name)

    def base_pose(self):
        d={'Spine':(.10 if self.heavy else .065 if self.thin else .014,0,0),
           'Head':(.12 if not self.hero else .018,0,0)}
        for side,sgn in [('L',-1),('R',1)]:
            d['UpperArm.'+side]=(-.025,.27*sgn,0)
            d['Forearm.'+side]=(-.25 if self.hero and side=='R' else -.055,.02*sgn,0)
        return d

    def action(self,name,length,sampler):
        action=bpy.data.actions.new(name);action.use_fake_user=True
        self.rig.animation_data.action=action
        for i in range(9):
            t=i/8
            d,z=sampler(t,self.base_pose())
            self.pose(1+length*t,d,z)
        self.rig.animation_data.action=None
        track=self.rig.animation_data.nla_tracks.new();track.name=name
        track.strips.new(name,1,action)
        track.mute=True

    def animate(self):
        self.rig.animation_data_create()
        def idle(t,d):
            w=math.sin(TAU*t)
            d['Chest']=(.025*w,0,.022*w)
            d['Head']=(d['Head'][0]+.025*w,.034*w,.06*math.sin(TAU*t))
            return d,.009*w
        def gait(t,d,run):
            w=math.sin(TAU*t)
            d['Spine']=(.19 if run else .055,0,.07*w)
            d['Chest']=(0,.036*w,-.09*w)
            for side,s in [('L',-1),('R',1)]:
                swing=w*s
                d['Thigh.'+side]=(swing*(.70 if run else .47),0,0)
                d['Shin.'+side]=(.09+max(0,-swing)*(.81 if run else .47),0,0)
                d['Foot.'+side]=(-swing*.13,0,0)
                d['UpperArm.'+side]=(-swing*(.47 if run else .29),s*.24,0)
                d['Forearm.'+side]=(-.38 if self.hero and side=='R' else -.15,0,0)
            return d,-.03+abs(w)*(.065 if run else .028)
        self.action('idle',60,idle)
        self.action('walk',24,lambda t,d:gait(t,d,False))
        self.action('run',16,lambda t,d:gait(t,d,True))
        def pose_clip(name,frames,keys):
            def at(t,d):
                i=next((i for i in range(len(keys)-1) if t<=keys[i+1][0]),len(keys)-2)
                ta,za,a=keys[i];tb,zb,b=keys[i+1]
                f=(t-ta)/(tb-ta);f=f*f*(3-2*f)
                for key in set(a)|set(b):
                    aa=a.get(key,d.get(key,(0,0,0)));bb=b.get(key,d.get(key,(0,0,0)))
                    d[key]=tuple(x+(y-x)*f for x,y in zip(aa,bb))
                return d,za+(zb-za)*f
            self.action(name,frames,at)
        def p(t,z,**a):
            return (t,z,{k.replace('_L','.L').replace('_R','.R'):v for k,v in a.items()})
        if self.hero:
            pose_clip('jump',8,[p(0,-.055,Thigh_L=(-.28,0,0),Thigh_R=(-.28,0,0),Shin_L=(.55,0,0),Shin_R=(.55,0,0)),p(.34,.01,UpperArm_L=(-.36,-.18,0),UpperArm_R=(-.20,.19,0)),p(1,0,Thigh_L=(-.58,0,0),Thigh_R=(-.30,0,0),Shin_L=(.68,0,0),Shin_R=(.51,0,0))])
            pose_clip('fall',12,[p(0,0,Thigh_L=(-.52,0,0),Thigh_R=(-.27,0,0),Shin_L=(.64,0,0),Shin_R=(.47,0,0)),p(.55,-.022,Thigh_L=(-.25,0,0),Thigh_R=(-.29,0,0),Shin_L=(.29,0,0),Shin_R=(.33,0,0),UpperArm_L=(-.22,-.09,0)),p(1,-.024,Thigh_L=(-.20,0,0),Thigh_R=(-.20,0,0),Shin_L=(.34,0,0),Shin_R=(.34,0,0))])
            pose_clip('land',7,[p(0,-.02,Thigh_L=(-.22,0,0),Thigh_R=(-.22,0,0),Shin_L=(.36,0,0),Shin_R=(.36,0,0)),p(.36,-.13,Spine=(.28,0,0),Thigh_L=(-.55,0,0),Thigh_R=(-.55,0,0),Shin_L=(.91,0,0),Shin_R=(.91,0,0)),p(1,0)])
            pose_clip('interact',18,[p(0,0),p(.45,-.02,Spine=(.18,0,0),UpperArm_L=(-.83,-.26,0),Forearm_L=(-.38,0,0),Head=(.19,0,0)),p(1,0)])
            pose_clip('lantern',17,[p(0,0),p(.47,0,UpperArm_R=(-.61,.22,0),Forearm_R=(-.79,0,0),Lantern=(.92,0,0),Head=(.12,0,.13)),p(1,0)])
            pose_clip('cast',20,[p(0,0),p(.32,0,UpperArm_L=(.28,-.18,0),Forearm_L=(-1.15,0,0)),p(.65,.024,UpperArm_L=(-1.31,-.19,0),Forearm_L=(-.16,0,0),Spine=(.11,0,0)),p(1,0,UpperArm_L=(-.74,-.25,0),Forearm_L=(-.30,0,0))])
            self.action('fish_hold',36,lambda t,d:({**d,'UpperArm.L':(-.74,-.25,0),'Forearm.L':(-.30+.055*math.sin(TAU*t),0,0)},0))
            pose_clip('hit',11,[p(0,0),p(.25,-.07,Spine=(-.37,.13,.17),UpperArm_L=(-.41,-.15,0),Head=(-.22,0,0)),p(1,0)])
        else:
            self.action('watch',66,lambda t,d:({**d,'Head':(.12,.10*math.sin(TAU*t),.16*math.sin(TAU*t))},.004*math.sin(TAU*t)))
            if self.heavy:
                pose_clip('attack',28,[p(0,0),p(.48,-.09,Spine=(-.27,0,0),UpperArm_L=(-1.81,-.09,0),UpperArm_R=(-1.81,.09,0),Forearm_L=(-.55,0,0),Forearm_R=(-.55,0,0)),p(.62,-.13,Spine=(.55,0,0),UpperArm_L=(-.86,-.21,0),UpperArm_R=(-.86,.21,0)),p(1,0)])
            else:
                pose_clip('attack',22,[p(0,0),p(.34,-.03,Chest=(0,0,-.44),UpperArm_R=(.30,.0,.31),Forearm_R=(-.66,0,0)),p(.49,-.06,Chest=(.36,0,.32),UpperArm_R=(-1.42,.06,-.16),Forearm_R=(-.11,0,0)),p(1,0)])
            pose_clip('recoil',15,[p(0,0),p(.32,-.025,Spine=(-.35,0,0),UpperArm_L=(-1.03,-.18,0),UpperArm_R=(-.80,.23,0),Head=(.3,.13,0)),p(1,0)])

def build(kind):
    # Fresh scene; the isolated Blender MCP host contains no user project.
    for o in list(bpy.context.scene.objects):bpy.data.objects.remove(o,do_unlink=True)
    for a in list(bpy.data.actions):bpy.data.actions.remove(a)
    c=Character(kind)
    c.make_rig();c.mesh();c.attach_skin();c.animate()
    scene=bpy.context.scene
    scene.render.fps=30;scene.frame_start=1;scene.frame_end=67
    model=PROJECT/'assets/models/characters'; model.mkdir(parents=True,exist_ok=True)
    src=PROJECT/'assets/source_blender/characters';src.mkdir(parents=True,exist_ok=True)
    art=PROJECT/'docs/art/characters';art.mkdir(parents=True,exist_ok=True)
    for t in c.rig.animation_data.nla_tracks:t.mute=False
    bpy.ops.object.select_all(action='DESELECT')
    c.rig.select_set(True)
    for o in c.rig.children:o.select_set(True)
    bpy.context.view_layer.objects.active=c.rig
    bpy.ops.export_scene.gltf(filepath=str(model/(kind+'_v01.glb')),export_format='GLB',use_selection=True,
        export_yup=True,export_skins=True,export_animations=True,export_animation_mode='NLA_TRACKS',
        export_frame_range=False,export_cameras=False,export_lights=False)
    for t in c.rig.animation_data.nla_tracks:t.mute=True
    idle=bpy.data.actions['idle']
    c.rig.animation_data.action=idle
    c.rig.animation_data.action_slot=idle.slots[0]
    scene.frame_set(1)
    def look(o,at):o.rotation_euler=(Vector(at)-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(3,-5,2.75))
    cam=bpy.context.object;look(cam,(0,0,.98));cam.data.type='ORTHO';cam.data.ortho_scale=2.50
    scene.camera=cam
    for loc,power,size,color in [((-3,-4,5),415,4,(.88,.95,1)),((3,2,4),485,3,(.80,.88,1)),((1,-2,3),96,3,(1,.85,.68))]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        o=bpy.context.object;look(o,(0,0,1));o.data.energy=power;o.data.size=size;o.data.color=color
    scene.world=bpy.data.worlds.new('Coastal studio');scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background')
    bg.inputs[0].default_value=(.23,.27,.29,1);bg.inputs[1].default_value=.65
    scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=24
    scene.render.resolution_x=640;scene.render.resolution_y=760;scene.render.resolution_percentage=100
    scene.render.filepath=str(art/(kind+'-blender.png'))
    bpy.ops.render.render(write_still=True)
    for o in list(scene.objects):
        if o.type in ('CAMERA','LIGHT'):o.hide_set(True)
    c.rig.hide_set(False)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active=c.rig
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                s=area.spaces.active;s.shading.color_type='MATERIAL'
                s.region_3d.view_location=(0,0,.98)
                s.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
                s.region_3d.view_distance=2.8;s.region_3d.view_perspective='ORTHO'
    scene.render.filepath='//character.png'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(src/(kind+'_v01.blend')))
    print('CHARACTER',kind,'BONES',len(c.rig.data.bones),'CLIPS',len(c.rig.animation_data.nla_tracks),
          'TRIANGLES',sum(len(o.data.loop_triangles) for o in c.rig.children))

for kind in ('keeper','shadow','drowned'):
    build(kind)
