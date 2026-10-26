import bpy
globals().update(bpy.app.driver_namespace['RS_BUILD'])
old_rig=bpy.data.collections.get('RS_PRESENTATION_NOT_EXPORTED')
if old_rig:
    for obj in list(old_rig.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(old_rig)
RIG=bpy.data.collections.new('RS_PRESENTATION_NOT_EXPORTED');bpy.context.scene.collection.children.link(RIG)
def rig_object(obj):
    for col in list(obj.users_collection):col.objects.unlink(obj)
    RIG.objects.link(obj);return obj
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02))
ground=rig_object(bpy.context.object);ground.name='PresentationGroundOnly'
mat=bpy.data.materials.new('PresentationGroundOnly');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.045,.052,.047,1);bs.inputs['Roughness'].default_value=.9
ground.data.materials.append(mat)
world=bpy.context.scene.world;world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.23,.28,.30,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.45
def light(name,at,power,color,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);RIG.objects.link(obj);obj.location=at
    obj.rotation_euler=(Vector((-1,0,3))-obj.location).to_track_quat('-Z','Y').to_euler()
light('OvercastKey',(0,-8,15),2100,(.81,.89,1),10)
light('ColdRim',(-9,4,13),1800,(.65,.78,1),8)
light('TransmitterFill',(8,-8,8),1200,(1,.84,.65),7)
data=bpy.data.cameras.new('RadioAssetCamera');cam=bpy.data.objects.new('RadioAssetCamera',data);RIG.objects.link(cam)
cam.location=(14,-22,15);cam.rotation_euler=(Vector((-1.85,.1,3.45))-cam.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=17.0;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1500;scene.render.resolution_y=1250;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
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
            space.region_3d.view_location=Vector((-1.8,0,3.5));space.region_3d.view_distance=17
            space.region_3d.view_rotation=cam.rotation_euler.to_quaternion();space.region_3d.view_perspective='PERSP'
            space.overlay.show_floor=False
scene.render.filepath=PREVIEW+'/blender-beauty.png'
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+'/A26_radio_station_v01.blend',compress=True)
print('RADIO_RENDER_START')
bpy.ops.render.render(write_still=True)
# Detail view of the working transmitter; only the render switches to the repaired source state.
for obj in COL.objects:
    group=obj.get('assembly')
    if group in ('PanelOnline','BatteryInstalled'):obj.hide_render=False
    elif group=='PanelFault':obj.hide_render=True
cam.location=(5,-9,4);cam.rotation_euler=(Vector((0,-2.8,.8))-cam.location).to_track_quat('-Z','Y').to_euler()
data.ortho_scale=3.5
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.filepath=PREVIEW+'/transmitter-detail.png'
bpy.ops.render.render(write_still=True)
# Restore and save the source in the game's default, unrepaired state and full asset view.
for obj in COL.objects:
    group=obj.get('assembly')
    if group in ('PanelOnline','BatteryInstalled'):obj.hide_render=True
    elif group=='PanelFault':obj.hide_render=False
cam.location=(14,-22,15);cam.rotation_euler=(Vector((-1.85,.1,3.45))-cam.location).to_track_quat('-Z','Y').to_euler()
data.ortho_scale=17.0
scene.render.resolution_x=1500;scene.render.resolution_y=1250;scene.render.filepath=PREVIEW+'/blender-beauty.png'
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+'/A26_radio_station_v01.blend',compress=True)
bpy.app.driver_namespace['RS_BUILD'].update(globals())
print('RADIO_RENDER_SAVED',PREVIEW)
