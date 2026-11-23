extends Control
## Старый фотоаппарат «Смена-8М»: видоискатель от первого лица, селфи, фото-моменты и альбом смены.
## P — фотоаппарат, ЛКМ/Пробел — снимок, Tab — селфи, колесо — приближение, Esc/P — убрать.
## Снимки сохраняются в user://photos/<смена>/ и в финале складываются в слайд-шоу.
const Geo = preload("res://scripts/geometry.gd")
const STATION = preload("res://scripts/interactable.gd")
const CAMERA_SPOT := Vector3(4.5, 1, -32.5)
const FILM := 36
const PAPER := Color("e9e3ce")
const GOLD := Color("deb777")
const TEAL := Color("8fd7c0")
## Запланированные фото-моменты. Каждый появляется днём на своём дне и ждёт снимка около минуты.
const MOMENTS := [
	{"id":"rainbow","day":2,"title":"Радуга над морем","hint":"Посмотрите на восток, в сторону причала","at":Vector3(70, 6, -10)},
	{"id":"seals","day":3,"title":"Тюлени на камнях","hint":"Они греются на камнях у восточного берега","at":Vector3(19.5, 0.6, -10.5)},
	{"id":"whale","day":5,"title":"Кит у горизонта","hint":"Над водой на северо-востоке бьёт фонтан","at":Vector3(48, 0, -34)},
	{"id":"ghost_ship","day":7,"title":"Корабль в тумане","hint":"С запада в тумане проходит старый корабль","at":Vector3(-58, 0, 6)},
	{"id":"cranes","day":9,"title":"Журавлиный клин","hint":"Птицы летят над островом на юг","at":Vector3(0, 24, -30)},
	{"id":"aurora","day":12,"title":"Северное сияние","hint":"Небо на севере светится зелёным","at":Vector3(-10, 30, -90)},
	{"id":"farewell","day":14,"title":"Селфи у катера","hint":"Сделайте селфи (Tab) у катера «Северный» перед отплытием","at":Vector3(-33, 2, -22),"selfie":true}
]

var game: Node
var font: Font
var has_camera := false
var active := false
var selfie := false
var yaw := 0.0
var pitch := 0.0
var fov := 55.0
var orbit := 0.0
var photos: Array = []
var run_id := ""
var shooting := false
var flash := 0.0
var toast := ""
var toast_time := 0.0
var moment := {}
var moment_node: Node3D
var moment_time := 0.0
var moments_done := {}
var moment_clock := 0.0
var station: Area3D
var prop: Node3D

func setup(owner_game: Node) -> void:
	game = owner_game
	font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_station()
	reset()

func reset() -> void:
	if active:
		close()
	has_camera = false
	photos.clear()
	moments_done.clear()
	_clear_moment()
	run_id = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	if is_instance_valid(prop):
		prop.show()

# ---------------------------------------------------------------- фотоаппарат на складе

func _make_station() -> void:
	station = Area3D.new()
	station.name = "Station_camera"
	station.set_script(STATION)
	station.set("station_id", "camera")
	station.set("display_name", "Старый фотоаппарат на полке")
	station.set("remaining", -1)
	station.position = CAMERA_SPOT
	station.collision_layer = 0
	station.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	shape.shape = sphere
	station.add_child(shape)
	var marker := Label3D.new()
	marker.name = "InteractionMarker"
	marker.text = "◆"
	marker.font_size = 38
	marker.pixel_size = .014
	marker.position.y = 2.3
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station.add_child(marker)
	game.world.add_child(station)
	game.stations.append(station)
	prop = Node3D.new()
	prop.name = "OldCamera"
	game.world.add_child(prop)
	prop.global_position = CAMERA_SPOT
	Geo.box(prop, "Crate", Vector3(0, .35, 0), Vector3(.7, .7, .55), Color("6a5236"))
	Geo.box(prop, "Body", Vector3(0, .8, 0), Vector3(.34, .2, .14), Color("2b2d30"))
	var lens := Geo.cylinder(prop, "Lens", Vector3(0, .8, .1), .07, .1, Color("15171a"))
	lens.rotation.x = PI / 2
	Geo.box(prop, "Strap", Vector3(0, .73, -.05), Vector3(.4, .02, .03), Color("4a3524"))

func intercept(id: String) -> int:
	if id != "camera":
		return -1
	if has_camera:
		return 0
	has_camera = true
	station.remaining = 0
	prop.hide()
	game.sound.cue("chime")
	game.feedback(CAMERA_SPOT, "ФОТОАППАРАТ «СМЕНА-8М»")
	game.alert("СТАРЫЙ ФОТОАППАРАТ", "P — видоискатель · ЛКМ — снимок · Tab — селфи · L — альбом", 7)
	game.notify("Внутри заряжена плёнка на %d кадров. Днём на острове бывают моменты, которые стоит сохранить." % FILM, 9)
	return 1

# ---------------------------------------------------------------- фото-моменты

func advance(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	flash = maxf(0, flash - delta * 2.5)
	station.remaining = 0 if has_camera else -1
	var dark: bool = (game.campaign.enabled and game.campaign.state.night) or game.is_night()
	if not moment.is_empty() and dark and String(moment.id) != "aurora":
		_clear_moment()
	if not moment.is_empty():
		moment_time -= delta
		_animate_moment(delta)
		if moment_time <= 0:
			game.alert("ФОТО-МОМЕНТ УПУЩЕН", String(moment.title), 3)
			_clear_moment()
		return
	if not has_camera or not game.playing or game.finished:
		return
	var night: bool = game.campaign.enabled and game.campaign.state.night
	if night or game.is_night():
		return
	moment_clock += delta
	for spec in MOMENTS:
		if int(spec.day) <= game.day and not moments_done.has(spec.id) and moment_clock > 18.0:
			if spec.id == "farewell" and game.day < 14:
				continue
			if spec.id == "aurora" and game.day < 12:
				continue
			_start_moment(spec)
			break

func _start_moment(spec: Dictionary) -> void:
	moment = spec
	moment_time = 75.0
	moment_clock = 0
	moments_done[spec.id] = "missed"
	moment_node = _build_moment(spec)
	game.sound.cue("chime")
	game.alert("◉ ФОТО-МОМЕНТ · " + String(spec.title).to_upper(), String(spec.hint) + "  ·  P — фотоаппарат", 6)

func _clear_moment() -> void:
	moment = {}
	moment_time = 0
	if is_instance_valid(moment_node):
		moment_node.queue_free()
	moment_node = null

func banner() -> Dictionary:
	if moment.is_empty():
		return {}
	return {"title":"◉ " + String(moment.title).to_upper(),"hint":String(moment.hint),"time":moment_time,"ratio":moment_time / 75.0}

func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	return material

func _build_moment(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Moment_" + String(spec.id)
	game.world.add_child(root)
	root.global_position = spec.at
	match String(spec.id):
		"rainbow":
			var colors := [Color("ff4b4b"), Color("ff9a3c"), Color("ffe35a"), Color("5fd36b"), Color("4aa8ff"), Color("8a5cff")]
			for i in colors.size():
				var band := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 38.0 - i * 1.6
				torus.outer_radius = 39.6 - i * 1.6
				torus.rings = 96
				band.mesh = torus
				band.rotation = Vector3(PI / 2, -0.35, 0)
				band.material_override = _glow(colors[i], .22)
				band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(band)
		"seals":
			for i in 3:
				var seal := Geo.sphere(root, "Seal", Vector3(i * 1.4 - 1.4, .35, (i % 2) * .8), Vector3(.5, .45, 1.3), Color("5a5f63"))
				seal.rotation.y = .6 + i * .5
				Geo.sphere(root, "Head", Vector3(i * 1.4 - 1.4 + .25, .6, (i % 2) * .8 + .55), Vector3(.32, .3, .34), Color("63696d"))
		"whale":
			Geo.sphere(root, "Back", Vector3(0, -.2, 0), Vector3(9, 2.2, 3.2), Color("1d2a33"))
			var tail := Node3D.new()
			tail.name = "Tail"
			tail.position = Vector3(-6, .4, 0)
			root.add_child(tail)
			Geo.box(tail, "Fluke", Vector3(0, 1.2, 0), Vector3(.5, .4, 4.2), Color("1d2a33"))
			var spout := MeshInstance3D.new()
			spout.name = "Spout"
			var cone := CylinderMesh.new()
			cone.top_radius = 1.6
			cone.bottom_radius = .15
			cone.height = 5
			spout.mesh = cone
			spout.position = Vector3(3, 3.4, 0)
			spout.material_override = _glow(Color("dfefff"), .35)
			root.add_child(spout)
		"ghost_ship":
			Geo.box(root, "Hull", Vector3(0, 1.4, 0), Vector3(16, 2.6, 4), Color("1a1f22"))
			for x in [-4.0, 1.0, 5.0]:
				Geo.box(root, "Mast", Vector3(x, 7, 0), Vector3(.3, 11, .3), Color("1a1f22"))
				Geo.box(root, "Sail", Vector3(x + .3, 7.5, 0), Vector3(.1, 6, 3.4), Color("6d7478"))
			for i in 4:
				var lamp := OmniLight3D.new()
				lamp.light_color = Color("ffcf7a")
				lamp.light_energy = 3.0
				lamp.omni_range = 7
				lamp.position = Vector3(-6 + i * 4, 3, 2.2)
				root.add_child(lamp)
		"cranes":
			for i in 11:
				var row := absi(i - 5)
				var crane := Node3D.new()
				crane.name = "Crane"
				crane.position = Vector3((i - 5) * 2.2, 0, row * 2.0)
				root.add_child(crane)
				Geo.sphere(crane, "Body", Vector3.ZERO, Vector3(.3, .25, 1.0), Color("dfe4e2"))
				for side in [-1, 1]:
					Geo.box(crane, "Wing", Vector3(side * .9, 0, 0), Vector3(1.6, .05, .45), Color("c9cfcc"))
		"aurora":
			for i in 4:
				var ribbon := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(160, 26 + i * 6)
				ribbon.mesh = quad
				ribbon.position = Vector3(i * 12 - 18, i * 5, i * -10)
				ribbon.rotation = Vector3(-.2, .1 * i, .08 * i)
				ribbon.material_override = _glow(Color("49ff9a").lerp(Color("6a7bff"), i * .3), .16)
				root.add_child(ribbon)
		"farewell":
			var glow := OmniLight3D.new()
			glow.light_color = Color("ffd9a0")
			glow.light_energy = 1.5
			glow.omni_range = 8
			root.add_child(glow)
	return root

func _animate_moment(delta: float) -> void:
	if not is_instance_valid(moment_node):
		return
	var t := 75.0 - moment_time
	match String(moment.id):
		"whale":
			moment_node.position.y = sin(t * .5) * 1.2
			moment_node.get_node("Spout").visible = fmod(t, 6.0) < 2.0
		"ghost_ship":
			moment_node.position.z += delta * 1.2
		"cranes":
			moment_node.position += Vector3(0, 0, delta * 3.2)
			for crane in moment_node.get_children():
				for wing in crane.get_children():
					if wing.name.begins_with("Wing"):
						wing.rotation.z = sin(t * 5.0) * .45 * signf(wing.position.x)
		"aurora":
			for i in moment_node.get_child_count():
				var ribbon: MeshInstance3D = moment_node.get_child(i)
				ribbon.material_override.albedo_color.a = .1 + .08 * sin(t * .8 + i)

# ---------------------------------------------------------------- фоторежим

func toggle() -> void:
	if active:
		close()
	else:
		open()

func open() -> void:
	if not has_camera:
		game.notify("Фотоаппарата пока нет. Говорят, старая «Смена» лежит где-то на складе.", 4)
		return
	if not game.playing or game.paused or game.finished or game.fishing.is_open() or game.expedition.sailing:
		return
	active = true
	selfie = false
	var facing: float = game.player.get_node("Visual").rotation.y
	yaw = facing
	pitch = -0.05
	orbit = 0.0
	fov = 55
	game.player.enabled = false
	game.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	game.camera.h_offset = 0
	game.camera.v_offset = 0
	game.camera.near = .08
	game.hud.game_ui.hide()
	STATION.hide_markers = true
	show()
	_place_camera()
	game.sound.interact("cook")

func close() -> void:
	active = false
	selfie = false
	STATION.hide_markers = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.fov = 75
	game.camera.near = .05
	game.player.get_node("Visual").show()
	game.player.enabled = game.playing and not game.paused and not game.finished
	if game.playing and not game.finished:
		game.hud.game_ui.show()
	hide()
	game.update_camera(0.0)

func _place_camera() -> void:
	var cam: Camera3D = game.camera
	var head: Vector3 = game.player.global_position + Vector3(0, 1.58, 0)
	cam.fov = fov
	if selfie:
		var dir := Vector3(sin(yaw + orbit), 0, cos(yaw + orbit))
		cam.global_position = head + dir * 1.9 + Vector3(0, .15 + pitch * 1.5, 0)
		cam.look_at(head + Vector3(0, -.12, 0), Vector3.UP)
		game.player.get_node("Visual").show()
		game.player.get_node("Visual").rotation.y = yaw + orbit
	else:
		var forward := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		cam.global_position = head + Vector3(sin(yaw), 0, cos(yaw)) * .32
		cam.look_at(cam.global_position + forward, Vector3.UP)
		game.player.get_node("Visual").hide()

func handle(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventMouseMotion:
		var motion: Vector2 = event.relative * .0035
		if selfie:
			orbit = clampf(orbit - motion.x, -1.3, 1.3)
			pitch = clampf(pitch - motion.y, -.4, .6)
		else:
			yaw -= motion.x
			pitch = clampf(pitch - motion.y, -1.1, 1.2)
		return true
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT: shoot()
			MOUSE_BUTTON_WHEEL_UP: fov = clampf(fov - 4, 18, 80)
			MOUSE_BUTTON_WHEEL_DOWN: fov = clampf(fov + 4, 18, 80)
			MOUSE_BUTTON_RIGHT: close()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_ENTER: shoot()
			KEY_TAB:
				selfie = not selfie
				pitch = 0.0
				orbit = 0.0
				if selfie:
					game.player.play_gesture("lantern", .6)
			KEY_ESCAPE, KEY_P: close()
		return true
	return event is InputEventKey

func _process(delta: float) -> void:
	if active:
		_place_camera()
		var turn := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		var tilt := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		if selfie:
			orbit = clampf(orbit - turn * delta * 1.4, -1.3, 1.3)
		else:
			yaw -= turn * delta * 1.4
			pitch = clampf(pitch + tilt * delta * 1.0, -1.1, 1.2)
	queue_redraw()

func shoot() -> void:
	if shooting:
		return
	if photos.size() >= FILM:
		toast = "Плёнка закончилась — %d кадров в альбоме (L)." % FILM
		toast_time = 3
		return
	shooting = true
	var subject := _moment_in_frame()
	var caption := _caption(subject)
	hide()
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() > 1280:
		image.resize(1280, roundi(1280.0 * image.get_height() / image.get_width()), Image.INTERPOLATE_BILINEAR)
	var dir := "user://photos/%s" % run_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/photo_%02d.png" % [dir, photos.size() + 1]
	image.save_png(path)
	photos.append({"path":path,"caption":caption,"day":game.day,"selfie":selfie,"moment":String(subject.get("id", ""))})
	show()
	flash = 1.0
	game.sound.cue("dispel")
	shooting = false
	if not subject.is_empty():
		moments_done[subject.id] = "taken"
		game.sanity = minf(100, game.sanity + 12)
		toast = "★ Фото-момент сохранён: %s" % String(subject.title)
		game.alert("★ " + String(subject.title).to_upper(), "Кадр в альбоме. Рассудок +12", 4)
		_clear_moment()
	else:
		toast = "Снимок %d / %d · %s" % [photos.size(), FILM, caption]
	toast_time = 3

func _moment_in_frame() -> Dictionary:
	if moment.is_empty() or not is_instance_valid(moment_node):
		return {}
	if bool(moment.get("selfie", false)):
		var near_ship: bool = game.player.global_position.distance_to(moment.at) < 14
		return moment if selfie and near_ship else {}
	var cam: Camera3D = game.camera
	var target: Vector3 = moment_node.global_position
	if not cam.is_position_in_frustum(target):
		return {}
	var screen := cam.unproject_position(target)
	var view := get_viewport_rect().size
	return moment if Rect2(view * .12, view * .76).has_point(screen) else {}

func _caption(subject: Dictionary) -> String:
	var place := "остров"
	if not subject.is_empty():
		place = String(subject.title)
	elif selfie:
		place = "селфи смотрителя"
	else:
		var nearest := 999.0
		for item in game.stations:
			var d: float = item.global_position.distance_to(game.player.global_position)
			if d < nearest and d < 14:
				nearest = d
				place = String(item.display_name).split("·")[0].strip_edges().to_lower()
	var time := "ночь" if game.is_night() else "день"
	return "День %02d · %s · %s" % [game.day, time, place]

# ---------------------------------------------------------------- видоискатель

func _draw() -> void:
	if not active:
		return
	var view := get_viewport_rect().size
	var frame := Rect2(view * .08, view * .84)
	var corner := 46.0
	var color := Color(1, 1, 1, .85)
	for p in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		var sx := 1.0 if p.x < view.x * .5 else -1.0
		var sy := 1.0 if p.y < view.y * .5 else -1.0
		draw_line(p, p + Vector2(corner * sx, 0), color, 3)
		draw_line(p, p + Vector2(0, corner * sy), color, 3)
	var c := view * .5
	draw_arc(c, 26, 0, TAU, 48, Color(1, 1, 1, .5), 1.5)
	draw_line(c - Vector2(8, 0), c + Vector2(8, 0), Color(1, 1, 1, .6), 1)
	draw_line(c - Vector2(0, 8), c + Vector2(0, 8), Color(1, 1, 1, .6), 1)
	draw_circle(frame.position + Vector2(30, 30), 7, Color("ff4b4b") if int(Time.get_ticks_msec() / 500) % 2 == 0 else Color(0, 0, 0, 0))
	draw_string(font, frame.position + Vector2(46, 37), "СМЕНА-8М  ·  %s" % ("СЕЛФИ" if selfie else "ВИДОИСКАТЕЛЬ"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	draw_string(font, Vector2(frame.end.x - 210, frame.position.y + 37), "КАДР %02d / %d" % [mini(photos.size() + 1, FILM), FILM], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	draw_string(font, Vector2(frame.position.x + 16, frame.end.y - 18), "ЛКМ / Пробел — снимок   ·   Tab — селфи   ·   мышь / WASD — навести   ·   колесо — зум   ·   Esc / P — убрать", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, .75))
	draw_string(font, Vector2(frame.end.x - 120, frame.end.y - 18), "%d мм" % roundi(35.0 * 55.0 / fov), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	if not moment.is_empty():
		var hint := "◉ " + String(moment.title) + " · " + ("в кадре!" if not _moment_in_frame().is_empty() else String(moment.hint))
		var width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_rect(Rect2(c.x - width * .5 - 14, frame.position.y + 56, width + 28, 32), Color(0, 0, 0, .5))
		draw_string(font, Vector2(c.x - width * .5, frame.position.y + 78), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD if _moment_in_frame().is_empty() else TEAL)
	if toast_time > 0:
		var width := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_rect(Rect2(c.x - width * .5 - 14, frame.end.y - 74, width + 28, 34), Color(0, 0, 0, .55))
		draw_string(font, Vector2(c.x - width * .5, frame.end.y - 50), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
	if flash > 0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, flash * .85))

# ---------------------------------------------------------------- сохранение

func save_data() -> Dictionary:
	return {"has_camera":has_camera,"photos":photos,"run_id":run_id,"moments":moments_done}

func restore(data: Dictionary) -> void:
	has_camera = bool(data.get("has_camera", false))
	run_id = String(data.get("run_id", run_id))
	photos = []
	for item in data.get("photos", []):
		if item is Dictionary and FileAccess.file_exists(String(item.get("path", ""))):
			photos.append(item)
	moments_done = data.get("moments", {})
	if is_instance_valid(prop):
		prop.visible = not has_camera
