import bpy
globals().update(bpy.app.driver_namespace['RS_BUILD'])
# Keep the printed frequency readable both on the unlit glass and the lit screen.
old=bpy.data.objects.get('Frequency1046')
if old:bpy.data.objects.remove(old,do_unlink=True)
for group,mat,name in [('PanelFault','RS_FadedIvory','FrequencyOff'),('PanelOnline','RS_DarkIron','FrequencyOn')]:
    obj=label(name,'104.6',(-.40,-3.255,.715),.11,mat,group)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH')
bpy.app.driver_namespace['RS_BUILD'].update(globals())
print('RADIO_DISPLAY_REVIEW_OK: separate readable 104.6 labels for off/on states')
