extends Control
var game: Node
var large := false

func _process(_delta: float) -> void:
	queue_redraw()

func point(world: Vector3) -> Vector2:
	var scale_factor := minf(size.x/78.0,(size.y-25)/80.0)
	return Vector2(size.x*0.5+(world.x+6)*scale_factor,(size.y-25)*0.5+(world.z+15)*scale_factor)

func ellipse(center: Vector3, radii: Vector2) -> void:
	var polygon := PackedVector2Array()
	for i in 64:
		var a := TAU*i/64.0
		polygon.append(point(center+Vector3(cos(a)*radii.x,0,sin(a)*radii.y)))
	draw_colored_polygon(polygon,Color("46554b"))
	draw_polyline(polygon+PackedVector2Array([polygon[0]]),Color("829084"),1)

func _draw() -> void:
	if not is_instance_valid(game): return
	ellipse(Vector3.ZERO,Vector2(21.5,17.5))
	ellipse(Vector3(-4,0,-28),Vector2(23,20))
	draw_line(point(Vector3(-23,0,-21)),point(Vector3(-33,0,-21)),Color("958568"),5 if large else 2)
	var vessel := Rect2(point(Vector3(-36.3,0,-33)),point(Vector3(-29.7,0,-16))-point(Vector3(-36.3,0,-33)))
	draw_rect(vessel,Color("897b61"))
	for station in game.stations:
		if station.is_available() and station.visible:
			draw_circle(point(station.position),2 if large else 1.6,Color("bda577"))
			if game.campaign.enabled and station.station_id==game.campaign.target_id():
				draw_arc(point(station.position),9 if large else 5,0,TAU,24,Color("8fd7c0"),2)
				if large:draw_line(point(game.player.position),point(station.position),Color(.56,.84,.75,.3),1)
	draw_circle(point(game.player.position),5 if large else 3,Color("ffebaf"))
	for enemy in game.enemies:
		if is_instance_valid(enemy): draw_circle(point(enemy.position),3 if large else 1.5,Color("bd8070"))
	if large:
		var labels := [["МАЯК",Vector3(-13,0,-8)],["ХИЖИНА",Vector3(5,0,3)],["РЫБАЛКА",Vector3(20,0,8)],["СКЛАД",Vector3(7,0,-30)],["КОЛОДЕЦ",Vector3(1,0,-20)],["РАДИО",Vector3(-14,0,-38)],["ОСТОВ",Vector3(12,0,-40)],["ГАВАНЬ",Vector3(-23,0,-17)],["КАТЕР",Vector3(-36,0,-34)],["ВАЛЕЖНИК",Vector3(-9,0,-26)]]
		for pair in labels:
			draw_string(ThemeDB.fallback_font,point(pair[1])+Vector2(-15,-8),pair[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e4d9b7"))
		draw_string(ThemeDB.fallback_font,Vector2(22,size.y-16),"● ВЫ    ◆ МЕСТА ДЕЙСТВИЙ    N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c3bd9d"))
	else:
		draw_string(ThemeDB.fallback_font,Vector2(10,size.y-10),"M — КАРТА  /  N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("91a9a4"))
