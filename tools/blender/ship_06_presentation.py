import bpy
globals().update(bpy.app.driver_namespace["SV_BUILD"])
RIG=bpy.data.collections.new("SV_PRESENTATION_NOT_EXPORTED")
bpy.context.scene.collection.children.link(RIG)
def rig_object(obj):
    for col in list(obj.users_collection):col.objects.unlink(obj)
    RIG.objects.link(obj)
    return obj
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.13))
water=rig_object(bpy.context.object);water.name="PresentationSea"
watermat=bpy.data.materials.new("PresentationSeaOnly");watermat.use_nodes=True
bs=watermat.node_tree.nodes.get("Principled BSDF")
bs.inputs["Base Color"].default_value=(.021,.036,.038,1)
bs.inputs["Roughness"].default_value=.23
bs.inputs["Metallic"].default_value=.35
noise_node=watermat.node_tree.nodes.new("ShaderNodeTexNoise")
noise_node.inputs["Scale"].default_value=1.6
noise_node.inputs["Detail"].default_value=3
bump=watermat.node_tree.nodes.new("ShaderNodeBump")
bump.inputs["Strength"].default_value=.13
bump.inputs["Distance"].default_value=.14
watermat.node_tree.links.new(noise_node.outputs["Fac"],bump.inputs["Height"])
watermat.node_tree.links.new(bump.outputs["Normal"],bs.inputs["Normal"])
water.data.materials.append(watermat)
world=bpy.context.scene.world;world.use_nodes=True
world.node_tree.nodes.get("Background").inputs["Color"].default_value=(.19,.24,.27,1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value=.6
def light(name,at,power,color,size):
    data=bpy.data.lights.new(name,"AREA");data.energy=power;data.shape="DISK";data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);RIG.objects.link(obj);obj.location=at;obj.rotation_euler=(Vector((0,1,1))-obj.location).to_track_quat("-Z","Y").to_euler()
light("ColdSoftbox",(4,-6,16),2100,(.77,.86,1),12)
light("WarmCabinRim",(-7,8,11),1700,(1,.86,.65),9)
light("FrontFill",(2,-13,7),900,(.9,.94,1),8)
camera_data=bpy.data.cameras.new("AssetCamera")
cam=bpy.data.objects.new("AssetCamera",camera_data);RIG.objects.link(cam)
cam.location=(23,-30,23)
cam.rotation_euler=(Vector((.2,.5,1.8))-cam.location).to_track_quat("-Z","Y").to_euler()
camera_data.type="ORTHO";camera_data.ortho_scale=25
bpy.context.scene.camera=cam
scene=bpy.context.scene
scene.render.engine="CYCLES";scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.filepath=PREVIEW+"/blender-beauty.png"
try:
    cp=bpy.context.preferences.addons["cycles"].preferences
    cp.compute_device_type="ONEAPI";cp.get_devices()
    devices=[d for d in cp.devices if d.type=="ONEAPI"]
    if devices:
        for d in cp.devices:d.use=d.type=="ONEAPI"
        scene.cycles.device="GPU"
    print("RENDER_DEVICES",[(d.name,d.type,d.use) for d in cp.devices])
except Exception as error:
    scene.cycles.device="CPU";print("CPU_RENDER",str(error))
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        area.spaces.active.shading.type="MATERIAL"
        area.spaces.active.region_3d.view_distance=27
        area.spaces.active.region_3d.view_location=Vector((0,0,2))
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+"/A37_coastal_vessel_v01.blend",compress=True)
print("RENDER_START")
bpy.ops.render.render(write_still=True)
print("RENDER_SAVED",scene.render.filepath)
