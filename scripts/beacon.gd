extends Node3D
## Поворот луча и реальный SpotLight3D используют один узел.

@export var powered: bool = true
var turn_speed := 0.22

func _process(delta: float) -> void:
	$BeamPivot.rotation.y += delta * turn_speed
	$BeamPivot.visible = powered
	$Lantern.light_energy = 3.5 if powered else 0.15

func set_powered(value: bool) -> void:
	powered = value
	if is_inside_tree():
		$BeamPivot.visible = value
