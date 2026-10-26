"""Run in Blender's Text Editor, or through Blender MCP.

F in Object Mode starts free navigation. Edit Mode keeps its usual F (Fill).
To undo this setup, set RESTORE = True and run the script again.
The original settings are backed up once in Blender's configuration folder.
"""
import bpy
import json
from pathlib import Path

RESTORE = False
BACKUP = Path(bpy.utils.user_resource('CONFIG', create=True)) / 'lighthouse_flight_navigation_backup.json'
inputs = bpy.context.preferences.inputs
walk = inputs.walk_navigation
config = bpy.context.window_manager.keyconfigs.user
keymap = config.keymaps.get('Object Mode')
if keymap is None:
    keymap = config.keymaps.new(name='Object Mode', space_type='EMPTY', region_type='WINDOW')


def is_flight_binding(item):
    return (item.idname == 'view3d.walk' and item.type == 'F'
            and item.value == 'PRESS' and not item.any
            and not item.shift and not item.ctrl and not item.alt and not item.oskey)


bindings = [item for item in keymap.keymap_items if is_flight_binding(item)]
if RESTORE:
    if not BACKUP.exists():
        raise RuntimeError('No original navigation settings have been backed up.')
    original = json.loads(BACKUP.read_text(encoding='utf-8'))
    if original['added_f_binding']:
        for item in bindings:
            keymap.keymap_items.remove(item)
    inputs.navigation_mode = original['navigation_mode']
    for name, value in original['walk'].items():
        setattr(walk, name, value)
    print('Original Blender navigation settings restored.')
else:
    conflicts = [item.idname for item in keymap.keymap_items
                 if item.active and item.type == 'F' and item.value == 'PRESS'
                 and not item.any and not item.shift and not item.ctrl
                 and not item.alt and not item.oskey and not is_flight_binding(item)]
    if conflicts:
        raise RuntimeError('F already has an Object Mode shortcut: ' + ', '.join(conflicts))
    if not BACKUP.exists():
        original = {
            'navigation_mode': inputs.navigation_mode,
            'walk': {name: getattr(walk, name) for name in
                     ('walk_speed', 'walk_speed_factor', 'mouse_speed', 'use_gravity')},
            'added_f_binding': not bool(bindings),
        }
        BACKUP.write_text(json.dumps(original, indent=2), encoding='utf-8')
    if not bindings:
        keymap.keymap_items.new('view3d.walk', 'F', 'PRESS')
    inputs.navigation_mode = 'WALK'
    walk.walk_speed = 3.0
    walk.walk_speed_factor = 5.0
    walk.mouse_speed = 0.8
    walk.use_gravity = False
    # Leave the render camera before navigating; the scene camera stays in place.
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == 'VIEW_3D':
                space = area.spaces.active
                if space.region_3d.view_perspective == 'CAMERA':
                    space.region_3d.view_perspective = 'PERSP'
                area.tag_redraw()
    print('F navigation enabled in Object Mode: WASD, Q/E, Shift fast, Alt slow.')
    print('Mouse wheel changes speed. Left mouse/Enter confirms; Esc cancels movement.')

bpy.context.window_manager.keyconfigs.update()
result = bpy.ops.wm.save_userpref()
print('Preferences saved:', result)
print('Backup:', BACKUP)
