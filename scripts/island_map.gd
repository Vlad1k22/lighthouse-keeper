extends Control
var game: Node

func _process(_delta: float) -> void:
	queue_redraw()

func point(world: Vector3) -> Vector2:
	return Vector2(size.x * 0.5 + world.x * 2.4, size.y * 0.5 + world.z * 2.4)

func _draw() -> void:
	if not is_instance_valid(game):
		return
	var polygon := PackedVector2Array()
	for index in 32:
		var a := TAU * index / 32.0
		polygon.append(Vector2(size.x * 0.5 + cos(a) * 52, size.y * 0.5 + sin(a) * 42))
	draw_colored_polygon(polygon, Color("4a625d"))
	draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color("90a59a"), 1)
	for station in game.stations:
		var color := Color("dab476") if station.station_id in ["beacon", "shelter", "fuel"] else Color("839f91")
		if station.is_available():
			draw_circle(point(station.position), 2.5, color)
	draw_circle(point(game.player.position), 3.7, Color("f4e9cc"))
	for enemy in game.enemies:
		if is_instance_valid(enemy):
			draw_circle(point(enemy.position), 2, Color("bd8070"))
	draw_string(ThemeDB.fallback_font, Vector2(10, size.y - 10), "ОСТРОВ  /  N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("91a9a4"))
