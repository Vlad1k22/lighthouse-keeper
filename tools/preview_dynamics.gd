extends SceneTree
## Скриншоты новой динамики для презентации: оборона ночью, дневное событие, подсказка цели.
## Запуск: godot --path . --script res://tools/preview_dynamics.gd
## Изолированная сцена: сохранения игрока не трогает.
const OUT := "res://docs/dynamics/"

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUT + name
	root.get_texture().get_image().save_png(path)
	print("Captured ", path)

func setup_day(game: Node, number: int) -> void:
	game.day = number
	game.campaign.state.day = number
	game.campaign.ensure_day()
	game.campaign.state.completed_days = range(1, number)
	game.expedition.state.merge({"tools":true,"battery":true,"signal":true,"pump":true,"last_dawn":number,"scrap":4}, true)
	game.expedition.update_visuals()
	game.barricade_built = true
	game.build_barricade()
	game.inventory.fuel = 2
	game.inventory.wood = 3

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.checkpoints_enabled = false
	game.save_path = "user://preview_dynamics.json"
	game.start_shift()
	game.hours_per_second = 0

	# 0. Первый день: утренняя сводка по радио и строка цели.
	game.player.position = Vector3(3, 1.1, 5.5)
	await create_timer(2.5).timeout
	game.hud.overlay.card_time = 0
	game.message_time = 0
	await create_timer(.3).timeout
	await shot("radio-briefing.png")
	game.radio.reset()

	# 1. Новый день: заставка и стрелка к цели.
	setup_day(game, 2)
	game.player.position = Vector3(16, 1.1, 6)
	game.camera_focus = game.player.position + Vector3(0, 1, 0)
	game.message_time = 0
	await create_timer(1.6).timeout
	await shot("day-title-card.png")
	game.hud.overlay.card_time = 0
	await create_timer(.2).timeout
	await shot("objective-guide.png")

	# 2. Дневное происшествие: ящик у берега с таймером.
	game.hud.overlay.card_time = 0
	setup_day(game, 5)
	game.player.position = Vector3(3, 1.1, 4)
	game.island_events.start("wreck")
	game.player.position = game.island_events.point + Vector3(-5, .2, -2.5)
	game.camera_focus = game.player.position + Vector3(0, 1, 0)
	game.hud.overlay.alert_time = 0
	game.message_time = 0
	await create_timer(1.4).timeout
	game.hud.overlay.card_time = 0
	await create_timer(.2).timeout
	await shot("day-event.png")
	game.island_events.finish_quietly()

	# 3. Ночная осада: тени идут к баррикаде, луч фонаря выжигает их.
	setup_day(game, 9)
	game.campaign.state.marks = {"0":true,"1":true}
	game.campaign.state.beacon_charge = 2
	game.lighthouse_on = true
	game.beacon.set_powered(true)
	game.player.lantern_on = true
	game.player.position = Vector3(4.6, 1.1, 8.2)
	game.campaign.begin_night()
	game.campaign.state.night_clock = 12
	game.hour = 22.5
	game.message_time = 0
	game.night_raids.advance(6)
	game.clear_enemies()
	for offset in [Vector3(-1.6, .3, 4.6), Vector3(1.4, .3, 5.4), Vector3(3.2, .3, 3.0)]:
		var enemy = game.spawn_shadow(game.player.position + offset, "drowned" if offset.x > 3 else "shadow")
		enemy.goal = "barricade"
		enemy.goal_point = game.night_raids.BARRICADE_FRONT
	for enemy in game.enemies:
		enemy.max_darkness = 5000
		enemy.darkness = 3000
	game.night_raids.barricade_hp = 64
	game.night_raids.dispelled = 3
	game.hud.overlay.card_time = 0
	game.hud.overlay.alert("ВОЛНА 3 · тени идут к баррикаде", "Защитите свет до рассвета", 30)
	game.lantern_beam.forced = true
	game.lantern_beam.aim_override = Vector3(.05, 0, 1)
	game.camera_focus = game.player.position + Vector3(0, 1, 2)
	game.target_zoom = 19
	game.camera_zoom = 19
	await create_timer(1.6).timeout
	game.hud.overlay.card_time = 0
	game.night_raids.dispelled = 3
	await create_timer(.2).timeout
	await shot("night-defense.png")
	quit()
