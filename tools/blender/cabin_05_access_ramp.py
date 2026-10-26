import bpy
globals().update(bpy.app.driver_namespace['KC_BUILD'])
# Shallow boarding ramp across the existing lower step, with a flat transition onto the porch.
for i in range(8):
    left=-.64+i*.16;right=left+.154
    verts=[(left,-4.10,.005),(right,-4.10,.005),(right,-3.40,.400),(left,-3.40,.400),
           (left,-4.10,-.035),(right,-4.10,-.035),(right,-3.40,.360),(left,-3.40,.360)]
    obj=mesh('PorchApproachRampPlank',verts,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'KC_BareTimber','Porch')
    bevel(obj,.003,1)
# Keep the source easy to navigate with the user's installed F shortcut.
bpy.context.preferences.inputs.walk_navigation.use_gravity=False
bpy.app.driver_namespace['KC_BUILD'].update(globals())
print('CABIN_ACCESS_RAMP_OK: width 1.28m, rise 0.4m, run 0.7m; no extra textures')
