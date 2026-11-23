extends SceneTree
## Выгружает реплики радиоэфира из scripts/radio_voice.gd в tools/voice/lines.json для генератора озвучки.
func _initialize() -> void:
	var lines: Dictionary = load("res://scripts/radio_voice.gd").LINES
	var file := FileAccess.open("res://tools/voice/lines.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(lines, "  "))
	file.close()
	print("Lines: ", lines.size())
	quit()
