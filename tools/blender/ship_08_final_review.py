import bpy
globals().update(bpy.app.driver_namespace["SV_BUILD"])
scene=bpy.context.scene
for obj in COL.objects:
    if obj.get("assembly") in ["StageHullRepaired","StageEngineReady"]: obj.hide_set(True)
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        area.spaces.active.region_3d.view_perspective="CAMERA"
        area.spaces.active.shading.type="MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=SOURCE+"/A37_coastal_vessel_v01.blend",compress=True)
scene.render.filepath=PREVIEW+"/blender-beauty.png"
bpy.ops.render.render(write_still=True)
print("FINAL_BEAUTY",scene.render.filepath)
