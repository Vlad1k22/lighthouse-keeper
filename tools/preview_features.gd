extends SceneTree
## Скриншоты новых занятий для презентации: мини-игры, каменоломня, укрепления, огород,
## видоискатель фотоаппарата, ночной таймер и причал. Запуск с экраном (не --headless):
## godot --path . --script res://tools/preview_features.gd
const OUT := "res://docs/features/"
var game: Node

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name)
	print("Captured ", OUT + name)

func clean() -> void:
	game.hud.overlay.card_time = 0
	game.hud.overlay.alert_time = 0
	game.message_time = 0
	game.radio.reset()

func focus(at: Vector3, zoom: float) -> void:
	game.player.position = at
	game.target_zoom = zoom
	game.camera_zoom = zoom
	game.camera_focus = at + Vector3(0, 1, 0)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.save_path = "user://preview_features.json"
	game.start_shift()
	game.hours_per_second = 0
	game.day = 6
	game.campaign.state.day = 6
	game.campaign.ensure_day()
	game.expedition.state.merge({"tools":true,"battery":true,"signal":true,"pump":true,"last_dawn":6,"scrap":6}, true)
	game.expedition.update_visuals()
	game.barricade_built = true
	game.build_barricade()
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	game.campaign.state.beacon_charge = 2
	game.inventory.wood = 30
	game.inventory.stone = 30
	game.photo.has_camera = true

	# 1. Мини-игра ремонта генератора.
	game.lighthouse_on = false
	game.beacon.set_powered(false)
	game.inventory.fuel = 1
	focus(Vector3(-6.4, 1.2, -4.7), 16)
	await create_timer(1.0).timeout
	clean()
	game.minigames.offer(game.homestead.station("quarry") if false else _station("beacon"))
	game.minigames.hits = 1
	game.minigames.needle = game.minigames.sector - .9
	await create_timer(.2).timeout
	await shot("minigame-repair.png")
	game.minigames.close()

	# 2. Жарка рыбы.
	game.fish_items.append(game.PROVISIONS.fish_item("mackerel", 900))
	game.sync_provisions()
	game.minigames.open_cook(_station("cook"))
	game.minigames.doneness = .7
	game.minigames.side = 1
	game.minigames.sides_good = 1
	await create_timer(.15).timeout
	await shot("minigame-cooking.png")
	game.minigames.close()

	# 3. Розжиг костра.
	game.minigames.open_fire(_station("fire"))
	game.minigames.stage = 1
	game.minigames.flame = .62
	game.minigames.steady = 1.3
	await create_timer(.15).timeout
	await shot("minigame-fire.png")
	game.minigames.close()
	game.lighthouse_on = true
	game.beacon.set_powered(true)

	# 4. Укрепления: дерево и камень вокруг хижины, огород с вороной.
	for id in ["fort_n", "fort_ne", "fort_nw", "fort_e", "fort_w", "fort_se"]:
		game.homestead.levels[id] = 2 if id in ["fort_n", "fort_e", "fort_se"] else 1
	game.homestead.levels.fort_front = 2
	game.homestead._refresh_visuals()
	game.homestead.beds[0] = {"stage":4,"water":true,"grow":0.0,"crop":0,"bird":false}
	game.homestead.beds[1] = {"stage":3,"water":true,"grow":0.0,"crop":1,"bird":false}
	game.homestead.beds[2] = {"stage":2,"water":false,"grow":0.0,"crop":2,"bird":false}
	for i in 3:
		game.homestead._refresh_bed(i)
	focus(Vector3(9.5, 1.2, 4.5), 17)
	game.homestead._spawn_bird(1)
	for i in 40:
		game.homestead._birds(.1)
	await create_timer(1.2).timeout
	clean()
	await shot("fortified-cabin-garden.png")

	# 5. Каменоломня.
	focus(Vector3(10.6, 1.2, -14.6), 12)
	await create_timer(1.2).timeout
	clean()
	await shot("quarry.png")

	# 6. Видоискатель фотоаппарата и фото-момент.
	focus(Vector3(16, 1.2, 2.5), 20)
	game.day = 2
	game.campaign.state.day = 2
	game.campaign.ensure_day()
	game.photo._start_moment(game.photo.MOMENTS[0])
	await create_timer(.5).timeout
	clean()
	game.photo.open()
	game.photo.yaw = atan2(1.0, -.1)
	game.photo.pitch = .12
	game.photo.fov = 60
	await create_timer(.4).timeout
	await shot("camera-viewfinder.png")
	game.photo.selfie = true
	game.photo.orbit = .4
	await create_timer(.4).timeout
	await shot("camera-selfie.png")
	game.photo.close()

	# 7. Ночь: таймер до рассвета и журнал без переполнения.
	game.day = 9
	game.campaign.state.day = 9
	game.campaign.ensure_day()
	for i in game.campaign.entry().goals.size():
		game.campaign.state.marks[str(i)] = true
	game.hunger = 80
	game.player.lantern_on = true
	focus(Vector3(5.5, 1.2, 7.5), 20)
	game.campaign.begin_night()
	game.campaign.state.night_clock = 21
	game.night_raids.advance(6)
	game.night_raids.next_wave = game.night_raids.clock + 5
	await create_timer(1.0).timeout
	clean()
	await shot("night-dawn-timer.png")

	# 8. Причал вблизи (без ряби).
	game.campaign.state.night = false
	game.hour = 11
	focus(Vector3(-25, 1.2, -21), 9)
	await create_timer(1.2).timeout
	clean()
	await shot("pier-closeup.png")
	quit()

func _station(id: String) -> Area3D:
	for item in game.stations:
		if item.station_id == id:
			return item
	return null
