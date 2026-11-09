extends Node3D
## Поворот луча и реальный SpotLight3D используют один узел.

@export var powered: bool = true:
	set(value):
		powered = value
		if is_node_ready():
			_apply_power()
var turn_speed := 0.22
var lens_material: StandardMaterial3D
var lens_color := Color.WHITE

func _ready() -> void:
	var lens := get_node_or_null("BlenderVisual/LH_Lens") as MeshInstance3D
	if lens != null:
		var source := lens.get_active_material(0) as StandardMaterial3D
		if source != null:
			lens_material = source.duplicate()
			lens_color = source.albedo_color
			lens.material_override = lens_material
	var glass := get_node_or_null("BlenderVisual/LH_Glass") as MeshInstance3D
	if glass != null:
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_power()

func _process(delta: float) -> void:
	$BeamPivot.rotation.y += delta * turn_speed

func _apply_power() -> void:
	$BeamPivot.visible = powered
	$Lantern.light_energy = 3.5 if powered else 0.15
	if lens_material != null:
		lens_material.emission_enabled = powered
		lens_material.albedo_color = lens_color if powered else Color("615144")

func set_powered(value: bool) -> void:
	powered = value
