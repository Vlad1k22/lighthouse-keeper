extends Control

var hud: CanvasLayer
var preferences
var resolution: OptionButton
var quality: OptionButton
var fullscreen: CheckButton
var sliders: Array[HSlider] = []
var status: Label

func setup(owner_hud: CanvasLayer, settings) -> void:
	hud = owner_hud
	preferences = settings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(.014,.031,.038,.94)
	add_child(backdrop)
	hud.panel(self,Rect2(360,134,720,632),Color("132a30"))
	hud.text(self,"СМОТРИТЕЛЬ МАЯКА  /  ПАРАМЕТРЫ",Rect2(404,171,616,27),14,hud.GOLD)
	hud.text(self,"Настройки",Rect2(404,212,616,53),38)
	hud.text(self,"Разрешение окна",Rect2(404,296,340,36),19)
	resolution = _option(Vector2(746,292))
	for size in preferences.SIZE_OPTIONS:
		resolution.add_item("%d × %d" % [size.x,size.y])
	hud.text(self,"Качество графики",Rect2(404,354,340,35),19)
	quality = _option(Vector2(746,350))
	quality.add_item("Экономное")
	quality.add_item("Высокое")
	hud.text(self,"Полноэкранный режим",Rect2(404,409,340,34),19)
	fullscreen = CheckButton.new()
	fullscreen.position = Vector2(746,404)
	fullscreen.size = Vector2(280,42)
	fullscreen.text = "Включить"
	add_child(fullscreen)
	fullscreen.toggled.connect(func(value): resolution.disabled = value)
	for i in 3:
		var y := 469 + i*51
		hud.text(self,["Звуки мира","Голос диспетчера","Музыка"][i],Rect2(404,y,340,33),18)
		var slider := HSlider.new()
		slider.position = Vector2(746,y+8)
		slider.size = Vector2(260,25)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .01
		add_child(slider)
		sliders.append(slider)
	status = hud.text(self,"",Rect2(405,618,615,24),14,hud.GOLD)
	hud.make_button(self,"Применить",Vector2(404,661),apply_settings,true).size.x = 287
	hud.make_button(self,"Назад · Esc",Vector2(725,661),close).size.x = 287
	hide()

func _option(at: Vector2) -> OptionButton:
	var button := OptionButton.new()
	button.position = at
	button.size = Vector2(260,43)
	button.add_theme_font_size_override("font_size",18)
	add_child(button)
	return button

func open() -> void:
	resolution.select(preferences.size_index)
	quality.select(1 if preferences.high_quality else 0)
	fullscreen.button_pressed = preferences.fullscreen
	resolution.disabled = preferences.fullscreen
	for i in sliders.size():
		sliders[i].value = preferences.volumes[i]
	status.text = ""
	show()
	if resolution.disabled:
		quality.grab_focus()
	else:
		resolution.grab_focus()

func close() -> void:
	hide()
	hud.settings_button.grab_focus()

func apply_settings() -> void:
	preferences.size_index = resolution.selected
	preferences.high_quality = quality.selected==1
	preferences.fullscreen = fullscreen.button_pressed
	for i in sliders.size():
		preferences.volumes[i] = sliders[i].value
	preferences.apply()
	status.text = "Настройки сохранены." if preferences.save_preferences()==OK else "Настройки применены. Сохранить файл не удалось."
