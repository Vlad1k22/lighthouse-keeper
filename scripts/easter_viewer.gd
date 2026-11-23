extends Control
## Крупный осмотр пасхалок: картинка во весь экран поверх игры (табличка фермы, портрет капитана, плакат).
## Открывается кнопкой E рядом с предметом, закрывается E / Esc / кликом.
const PAPER := Color("e8d9b5")
const GOLD := Color("dfb976")
var game: Node
var texture: Texture2D
var title := ""
var caption := ""
var appear := 0.0
var on_close: Callable

func setup(owner_game: Node) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func open(image: Texture2D, heading: String, text: String, closed: Callable = Callable()) -> void:
	texture = image
	title = heading
	caption = text
	on_close = closed
	appear = 0.0
	show()
	game.paused = true
	game.player.enabled = false
	queue_redraw()

func close() -> void:
	if not visible:
		return
	hide()
	game.paused = false
	game.player.enabled = not game.fishing.is_open()
	game.interaction_cooldown = .35
	if on_close.is_valid():
		on_close.call()

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_E, KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			close()
	elif event is InputEventMouseButton and event.pressed:
		close()

func _process(delta: float) -> void:
	if visible and appear < 1.0:
		appear = minf(1.0, appear + delta * 4.5)
		queue_redraw()

func _draw() -> void:
	if texture == null:
		return
	var view := size
	var ease := 1.0 - pow(1.0 - appear, 3.0)
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.04, 0.05, .9 * ease))
	var font := ThemeDB.fallback_font
	var room := Vector2(view.x * .78, view.y * .66)
	var image := Vector2(texture.get_width(), texture.get_height())
	var scale := minf(room.x / image.x, room.y / image.y)
	var shown := image * scale * lerpf(.92, 1.0, ease)
	var top := view.y * .07 + 44
	var at := Vector2((view.x - shown.x) * .5, top + (room.y - shown.y) * .5)
	draw_string(font, Vector2(0, view.y * .07 + 18), title, HORIZONTAL_ALIGNMENT_CENTER, view.x, 30, Color(GOLD, ease))
	draw_rect(Rect2(at - Vector2(10, 10), shown + Vector2(20, 20)), Color(0.07, 0.05, 0.03, ease))
	draw_rect(Rect2(at - Vector2(10, 10), shown + Vector2(20, 20)), Color(GOLD, .55 * ease), false, 2.0)
	draw_texture_rect(texture, Rect2(at, shown), false, Color(1, 1, 1, ease))
	var text_top := top + room.y + 46
	var width := minf(980.0, view.x * .8)
	draw_multiline_string(font, Vector2((view.x - width) * .5, text_top), caption, HORIZONTAL_ALIGNMENT_CENTER, width, 19, 4, Color(PAPER, ease))
	draw_string(font, Vector2(0, view.y - 26), "E / Esc / клик — закрыть", HORIZONTAL_ALIGNMENT_CENTER, view.x, 15, Color(.7, .72, .68, .8 * ease))
