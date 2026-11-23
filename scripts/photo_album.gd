extends Control
## Альбом снимков (L) и финальное слайд-шоу «Ваш остров» после прохождения.
const PAPER := Color("e9e3ce")
const GOLD := Color("deb777")
const INK := Color(0.02, 0.05, 0.07, 0.96)
const SLIDE := 3.6

var game: Node
var font: Font
var mode := ""
var textures: Array = []
var captions: Array = []
var page := 0
var reel_time := 0.0
var reel_done: Callable

func setup(owner_game: Node) -> void:
	game = owner_game
	font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func _load(photos: Array) -> void:
	textures.clear()
	captions.clear()
	for item in photos:
		var image := Image.load_from_file(ProjectSettings.globalize_path(String(item.path)))
		if image == null or image.is_empty():
			continue
		textures.append(ImageTexture.create_from_image(image))
		captions.append(String(item.caption) + ("  ★" if not String(item.get("moment", "")).is_empty() else ""))

func open_album() -> void:
	if game.photo.photos.is_empty():
		game.notify("Альбом пуст. %s" % ("P — фотоаппарат, ЛКМ — снимок." if game.photo.has_camera else "Сначала найдите старый фотоаппарат на складе."), 4)
		return
	_load(game.photo.photos)
	mode = "album"
	page = textures.size() - 1
	game.paused = true
	game.player.enabled = false
	show()

func play_reel(photos: Array, done: Callable) -> bool:
	_load(photos)
	if textures.is_empty():
		return false
	mode = "reel"
	page = -1
	reel_time = 0
	reel_done = done
	show()
	return true

func close() -> void:
	var was_reel := mode == "reel"
	mode = ""
	hide()
	if was_reel:
		if reel_done.is_valid():
			reel_done.call()
		return
	game.paused = false
	game.player.enabled = game.playing and not game.finished

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE, KEY_L, KEY_E:
				close()
			KEY_LEFT, KEY_A:
				page = posmod(page - 1, maxi(1, textures.size()))
			KEY_RIGHT, KEY_D, KEY_SPACE:
				if mode == "reel":
					reel_time = (page + 2) * SLIDE
				else:
					page = posmod(page + 1, maxi(1, textures.size()))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "reel":
			close()
		else:
			page = posmod(page + 1, maxi(1, textures.size()))

func _process(delta: float) -> void:
	if not visible:
		return
	if mode == "reel":
		reel_time += delta
		page = int(reel_time / SLIDE) - 1
		if page >= textures.size() + 1:
			close()
			return
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.02, 0.03, 1.0 if mode == "reel" else .93))
	if mode == "reel":
		_draw_reel(view)
	else:
		_draw_album(view)

func _fit(texture: Texture2D, area: Rect2, zoom := 1.0) -> Rect2:
	var size := texture.get_size()
	var scale := minf(area.size.x / size.x, area.size.y / size.y) * zoom
	var drawn := size * scale
	return Rect2(area.get_center() - drawn * .5, drawn)

func _centered(content: String, y: float, size_px: int, color: Color) -> void:
	var width := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(font, Vector2(get_viewport_rect().size.x * .5 - width * .5, y), content, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw_album(view: Vector2) -> void:
	_centered("АЛЬБОМ СМОТРИТЕЛЯ  ·  %d / %d" % [page + 1, textures.size()], 56, 22, GOLD)
	var area := Rect2(view.x * .12, 80, view.x * .76, view.y - 260)
	var texture: Texture2D = textures[page]
	var rect := _fit(texture, area)
	draw_rect(rect.grow(10), PAPER)
	draw_texture_rect(texture, rect, false)
	_centered(String(captions[page]), rect.end.y + 44, 19, PAPER)
	var strip_y := view.y - 120
	var thumb := Vector2(96, 60)
	var first := clampi(page - 5, 0, maxi(0, textures.size() - 11))
	for i in range(first, mini(textures.size(), first + 11)):
		var at := Vector2(view.x * .5 - 5.5 * (thumb.x + 8) + (i - first) * (thumb.x + 8), strip_y)
		var r := Rect2(at, thumb)
		draw_texture_rect(textures[i], r, false)
		if i == page:
			draw_rect(r.grow(3), GOLD, false, 3)
	_centered("← / → — листать   ·   Esc / L — закрыть", view.y - 24, 14, Color(PAPER.r, PAPER.g, PAPER.b, .6))

func _draw_reel(view: Vector2) -> void:
	if page < 0:
		var fade := minf(1, reel_time / 1.0)
		_centered("ВАШ ОСТРОВ", view.y * .45, 52, Color(PAPER.r, PAPER.g, PAPER.b, fade))
		_centered("%d снимков смены смотрителя" % textures.size(), view.y * .45 + 48, 20, Color(GOLD.r, GOLD.g, GOLD.b, fade))
		return
	if page >= textures.size():
		var fade := minf(1, (reel_time - (textures.size() + 1) * SLIDE) / .8 + 1)
		_centered("Свет горел до самого утра.", view.y * .45, 34, Color(PAPER.r, PAPER.g, PAPER.b, fade))
		_centered("Спасибо за смену, смотритель.", view.y * .45 + 46, 20, Color(GOLD.r, GOLD.g, GOLD.b, fade))
		return
	var local := fmod(reel_time, SLIDE)
	var alpha := clampf(minf(local / .6, (SLIDE - local) / .6), 0, 1)
	var texture: Texture2D = textures[page]
	var rect := _fit(texture, Rect2(view * .08, view * Vector2(.84, .74)), 1.0 + local * .02)
	draw_rect(rect.grow(12), Color(PAPER.r, PAPER.g, PAPER.b, alpha))
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
	_centered(String(captions[page]), rect.end.y + 52, 22, Color(PAPER.r, PAPER.g, PAPER.b, alpha))
	_centered("ЛКМ — пропустить", view.y - 22, 13, Color(1, 1, 1, .35))
