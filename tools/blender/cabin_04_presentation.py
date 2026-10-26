import bpy
globals().update(bpy.app.driver_namespace['KC_BUILD'])
RIG=bpy.data.collections.new('KC_PRESENTATION_NOT_EXPORTED');bpy.context.scene.collection.children.link(RIG)
def rig_object(obj):
    for col in list(obj.users_collection):col.objects.unlink(obj)
    RIG.objects.link(obj);return obj
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02))
ground=rig_object(bpy.context.object);ground.name='PresentationGroundOnly'
mat=bpy.data.materials.new('PresentationGroundOnly');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.045,.051,.046,1);bs.inputs['Roughness'].default_value=.9
ground.data.materials.append(mat)
world=bpy.context.scene.world;world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.23,.28,.30,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.45
def area_light(name,at,power,color,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);RIG.objects.link(obj);obj.location=at
    obj.rotation_euler=(Vector((0,0,1.8))-obj.location).to_track_quat('-Z','Y').to_euler()
area_light('OvercastKey',(0,-6,11),1400,(.81,.89,1),8)
area_light('CoolRim',(-5,4,7),1200,(.65,.78,1),6)
area_light('WarmPorchFill',(6,-7,6),850,(1,.84,.65),5)
data=bpy.data.lights.new('EntryLamp','POINT');data.energy=12;data.color=(1,.61,.26);data.shadow_soft_size=.14
obj=bpy.data.objects.new('EntryLamp',data);obj.location=(.94,-2.65,1.95);RIG.objects.link(obj)
data=bpy.data.cameras.new('CabinAssetCamera');cam=bpy.data.objects.new('CabinAssetCamera',data);RIG.objects.link(cam)
cam.location=(10,-13,8.5);cam.rotation_euler=(Vector((0,-.2,2.05))-cam.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=11.5;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=PREVIEW+'/blender-beauty.png'
try:
    cp=bpy.context.preferences.addons['cycles'].preferences;cp.compute_device_type='ONEAPI';cp.get_devices()
    gpu=[d for d in cp.devices if d.type=='ONEAPI']
    for d in cp.devices:d.use=d.type=='ONEAPI'
    scene.cycles.device='GPU' if gpu else 'CPU'
except Exception:scene.cycles.device='CPU'
for window in bpy.context.window_manager.windows:
    for area in window.screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.shading.type='MATERIAL'
            space.region_3d.view_distance=11.5;space.region_3d.view_location=Vector((0,-.2,2))
            space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            space.region_3d.view_perspective='PERSP'
            space.overlay.show_floor=False
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+'/A04_keeper_cabin_v01.blend',compress=True)
bpy.app.driver_namespace['KC_BUILD'].update(globals())
print('CABIN_RENDER_START')
bpy.ops.render.render(write_still=True)
print('CABIN_RENDER_SAVED',scene.render.filepath)
