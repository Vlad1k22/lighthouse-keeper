extends Area3D
## Area3D на карте: идентификатор события и запас собираемого ресурса.

@export var station_id: String = ""
@export var display_name: String = ""
@export var remaining: int = -1
var selected := false
var marker_clock := 0.0

func _process(delta: float) -> void:
	marker_clock += delta
	if has_node("InteractionMarker"):
		var marker: Label3D = $InteractionMarker
		marker.visible = is_available()
		marker.position.y = 2.3 + sin(marker_clock * 2.2) * 0.08
		marker.modulate = Color("ffe0a0") if selected else Color(0.8, 0.71, 0.48, 0.6)
		marker.scale = Vector3.ONE * (1.15 if selected else 0.8)
	if has_node("SelectionRing"):
		$SelectionRing.visible = selected and is_available()
		$SelectionRing.scale = Vector3.ONE * (1.0 + sin(marker_clock * 3) * 0.025)

func _ready() -> void:
	add_to_group("interactables")

func is_available() -> bool:
	return remaining != 0

func consume() -> void:
	if remaining > 0:
		remaining -= 1
	if remaining == 0:
		for child in get_children():
			if child is Label3D:
				child.hide()
