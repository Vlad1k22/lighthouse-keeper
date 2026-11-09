extends RefCounted

const GRAMOPHONE = preload("res://assets/models/interiors/gramophone.glb")
const RECORD = preload("res://assets/audio/music/gramophone.wav")
const GRAMOPHONE_AT := Vector3(-2.43,0,1.51)
const CREW_LOG_AT := Vector3(1.52,.68,1.93)
var game: Node
var record_player: AudioStreamPlayer3D

func install_cabin(room: Node3D) -> void:
	if room.has_node("Gramophone"):
		return
	var prop := GRAMOPHONE.instantiate() as Node3D
	prop.name = "Gramophone"
	prop.position = GRAMOPHONE_AT
	room.add_child(prop)
	var body := StaticBody3D.new()
	prop.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.61,.78,.52)
	collision.shape = shape
	collision.position.y = .39
	body.add_child(collision)
	record_player = AudioStreamPlayer3D.new()
	record_player.stream = game.sound.repeat_track(RECORD)
	record_player.bus = "Music"
	record_player.volume_db = -10
	record_player.unit_size = 1.9
	record_player.max_distance = 6.8
	record_player.position.y = 1.06
	prop.add_child(record_player)

func stop_record() -> void:
	if is_instance_valid(record_player):
		record_player.stop()

func nearby() -> String:
	var id: String = game.building_interiors.active
	if id not in ["cabin","ship"]:
		return ""
	var room := game.building_interiors.instances[id] as Node3D
	var target := GRAMOPHONE_AT if id=="cabin" else CREW_LOG_AT
	var offset: Vector3 = room.to_local(game.player.global_position)-target
	if Vector2(offset.x,offset.z).length()>.91:
		return ""
	return "gramophone" if id=="cabin" else "crew_log"

func prompt() -> String:
	match nearby():
		"gramophone":
			return "[E] Остановить пластинку" if record_player.playing else "[E] Завести граммофон"
		"crew_log":
			return "[E] Листок под койкой"
	return ""

func interact() -> bool:
	match nearby():
		"gramophone":
			if record_player.playing:
				stop_record()
			else:
				record_player.play()
			game.interaction_cooldown = .28
			return true
		"crew_log":
			game.unlock_story("crew_log")
			return true
	return false
