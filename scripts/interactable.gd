extends Area3D
## Area3D на карте: идентификатор события и запас собираемого ресурса.

@export var station_id: String = ""
@export var display_name: String = ""
@export var remaining: int = -1

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
