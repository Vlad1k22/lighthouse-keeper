extends Control
## Optional careful salvage uses the same daily allowance as the ordinary E action.
const CENTERS := [.68,.36,.57]
const TRACK := Rect2(454,405,532,27)
var game: Node
var hud: CanvasLayer
var station: Area3D
var bar: ColorRect
var zone: ColorRect
var cursor: ColorRect
var counter: Label
var result: Label
var progress := 0.0
var rounds := 0
var hits := 0
var width := .26
var speed := .65

static func profile(day: int) -> Vector2:
	if day>=10:return Vector2(.16,.95)
	if day>=5:return Vector2(.21,.79)
	return Vector2(.26,.65)

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	game = hud.game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(.012,.028,.030,.9)
	add_child(shade)
	hud.panel(self,Rect2(402,232,636,428),Color("132a2d"))
	hud.text(self,"СТАРЫЙ СКЛАД   /   РАБОЧИЙ СТОЛ",Rect2(454,264,532,25),14,hud.GOLD)
	hud.text(self,"Аккуратный разбор",Rect2(454,300,532,45),29)
	hud.text(self,"Нажмите пробел, когда метка попадёт в зелёную зону.",Rect2(454,361,532,31),16)
	bar = _strip(Color("0b1d21"))
	bar.position = TRACK.position
	bar.size = TRACK.size
	zone = _strip(Color("7da992"))
	cursor = _strip(Color("eed9aa"))
	cursor.size = Vector2(5,TRACK.size.y+8)
	counter = hud.text(self,"",Rect2(454,461,532,29),16,hud.GOLD)
	result = hud.text(self,"",Rect2(454,498,532,42),15,hud.MUTED)
	hud.make_button(self,"Остановить метку · Пробел",Vector2(454,550),strike,true).size.x = 315
	hud.make_button(self,"Отмена · Esc",Vector2(782,550),cancel).size.x = 204
	hide()

func _strip(color: Color) -> ColorRect:
	var strip := ColorRect.new()
	strip.color = color
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	return strip

func station_in_reach() -> Area3D:
	if game.day<2 or game.lighthouse_interior.active or game.expedition.used("scrap") or game.campaign.reserves_action("scrap"):
		return null
	for item in game.stations:
		if item.station_id=="scrap" and item.is_available() and game.station_distance(item)<=game.station_reach():
			return item
	return null

func open() -> void:
	station = station_in_reach()
	if station==null or game.player.jump_in_progress:
		game.notify("Для разбора подойдите к запасам деталей на старом складе. Доступно один раз в день.")
		return
	var tuning := profile(game.day)
	width = tuning.x
	speed = tuning.y
	progress = .05
	rounds = 0
	hits = 0
	result.text = "За точность начисляются дополнительные детали."
	game.paused = true
	game.player.enabled = false
	show()
	_refresh()

func _process(delta: float) -> void:
	if visible:
		progress = fposmod(progress + delta*speed,2.0)
		cursor.position = TRACK.position+Vector2(_position()*TRACK.size.x-2.5,-4)

func _position() -> float:
	return progress if progress<1 else 2-progress

func _refresh() -> void:
	var center: float = CENTERS[rounds]
	zone.position = TRACK.position + Vector2((center-width*.5)*TRACK.size.x,0)
	zone.size = Vector2(width*TRACK.size.x,TRACK.size.y)
	cursor.position = TRACK.position+Vector2(_position()*TRACK.size.x-2.5,-4)
	counter.text = "Крепление %d из %d   ·   Точно снято %d" % [rounds+1,CENTERS.size(),hits]

func strike() -> void:
	if not visible:
		return
	var hit := absf(_position()-float(CENTERS[rounds]))<=width*.5
	hits += int(hit)
	rounds += 1
	if rounds == CENTERS.size():
		_finish()
		return
	result.text = "Крепление снято аккуратно." if hit else "Крепление сорвалось. Основные детали всё ещё можно забрать."
	progress = .05
	_refresh()

func _finish() -> void:
	var target := station
	var bonus := maxi(0,hits-1)
	var before := int(game.expedition.state.scrap)
	cancel()
	if game.attempt_interaction(target) and int(game.expedition.state.scrap)==before+2:
		game.expedition.state.scrap += bonus
		game.notify("Разбор завершён. Детали +%d%s." % [2+bonus, " · за точность +%d" % bonus if bonus>0 else ""])

func cancel() -> void:
	if not visible:
		return
	hide()
	station = null
	game.paused = false
	game.player.enabled = game.playing and not game.finished
