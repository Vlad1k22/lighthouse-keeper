extends RefCounted

const SIZE_OPTIONS := [Vector2i(960,600),Vector2i(1280,800),Vector2i(1440,900),Vector2i(1600,1000),Vector2i(1920,1080)]
const CHANNELS := ["Environment", "Dialogue", "Music"]
const SETTINGS_FILE := "user://game_settings.cfg"

var game: Node
var path := SETTINGS_FILE
var size_index := 1
var fullscreen := false
var high_quality := true
var volumes := [.85, 1.0, .72]

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		size_index = clampi(int(config.get_value("video","size",1)),0,SIZE_OPTIONS.size()-1)
		fullscreen = bool(config.get_value("video","fullscreen",false))
		high_quality = bool(config.get_value("video","high_quality",true))
		for i in CHANNELS.size():
			volumes[i] = clampf(float(config.get_value("audio",CHANNELS[i],volumes[i])),0,1)
	apply()

func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("video","size",size_index)
	config.set_value("video","fullscreen",fullscreen)
	config.set_value("video","high_quality",high_quality)
	for i in CHANNELS.size():
		config.set_value("audio",CHANNELS[i],volumes[i])
	return config.save(path)

func apply() -> void:
	for i in CHANNELS.size():
		apply_volume(i,volumes[i])
	var viewport := game.get_viewport() as Viewport
	viewport.msaa_3d = Viewport.MSAA_4X if high_quality else Viewport.MSAA_DISABLED
	var sun := game.world.get_node("Sun") as DirectionalLight3D
	sun.shadow_enabled = high_quality
	if DisplayServer.get_name()=="headless" or "--keep-window-size" in OS.get_cmdline_user_args():
		return
	var window := game.get_window() as Window
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		var restored := window.mode != Window.MODE_WINDOWED
		window.mode = Window.MODE_WINDOWED
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		var preferred: Vector2i = SIZE_OPTIONS[size_index]
		var maximum := usable.size - Vector2i(24,72)
		var scale := minf(1.0,minf(float(maximum.x)/preferred.x,float(maximum.y)/preferred.y))
		var target := Vector2i(Vector2(preferred)*scale)
		if restored or window.size!=target:
			window.size = target
			window.position = usable.position + (usable.size - target)/2

func apply_volume(index: int, volume: float) -> void:
	var channel: String = CHANNELS[index]
	var bus := AudioServer.get_bus_index(channel)
	if bus<0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,channel)
	volumes[index] = clampf(volume,0,1)
	AudioServer.set_bus_mute(bus,volumes[index]<=0.0)
	AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(.001,volumes[index])))
