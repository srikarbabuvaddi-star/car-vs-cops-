extends SceneTree

func _init() -> void:
	call_deferred("_run_integration_tests")

func _run_integration_tests() -> void:
	print("=== RUNNING FULL GAME INTEGRATION TESTS ===")

	# 1. Test MainMenu Scene
	var err = change_scene_to_file("res://scenes/MainMenu.tscn")
	if err != OK:
		printerr("FAIL: Could not load MainMenu.tscn: ", err)
		quit(1)
		return

	await process_frame
	await process_frame

	var menu = current_scene as MainMenu
	if not menu:
		printerr("FAIL: MainMenu instance not found")
		quit(1)
		return

	var play_btn = menu.get_node_or_null("Margin/VBox/MenuButtons/PlayButton") as Button
	var levels_btn = menu.get_node_or_null("Margin/VBox/MenuButtons/LevelsButton") as Button
	if not play_btn or not levels_btn:
		printerr("FAIL: MainMenu buttons missing")
		quit(1)
		return
	print("PASS: MainMenu loaded with functional navigation buttons.")

	# 2. Test SoundManager
	if not SoundManager.instance:
		printerr("FAIL: SoundManager instance not created")
		quit(1)
		return
	SoundManager.instance.play_blip()
	SoundManager.instance.play_pickup()
	SoundManager.instance.play_crash()
	SoundManager.instance.play_close_call()
	print("PASS: SoundManager procedural SFX playback verified.")

	# 3. Test Game Scene & GameController
	SaveManager.data["target_level"] = 1
	err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not change to Game.tscn: ", err)
		quit(1)
		return

	await process_frame
	await process_frame
	await process_frame

	var game = current_scene as GameController
	if not game:
		printerr("FAIL: GameController not attached to Game.tscn")
		quit(1)
		return
	print("PASS: GameController active in Game.tscn.")

	# Verify all subsystem connections
	if not is_instance_valid(game.player):
		printerr("FAIL: Player reference missing in GameController")
		quit(1)
		return
	if not is_instance_valid(game.level_mgr):
		printerr("FAIL: LevelManager missing in GameController")
		quit(1)
		return
	if not is_instance_valid(game.score_mgr):
		printerr("FAIL: ScoreManager missing in GameController")
		quit(1)
		return
	if not is_instance_valid(game.heat_mgr):
		printerr("FAIL: HeatManager missing in GameController")
		quit(1)
		return
	if not is_instance_valid(game.spawner):
		printerr("FAIL: PoliceSpawner missing in GameController")
		quit(1)
		return
	if not is_instance_valid(game.hud):
		printerr("FAIL: HUD missing in GameController")
		quit(1)
		return
	print("PASS: All GameController subsystems (Player, Level, Score, Heat, Spawner, HUD) bound.")

	# 4. Simulate Driving & Survival Physics
	game.player.current_speed = 22.0
	for i in range(25):
		await process_frame
		await physics_frame

	print("PASS: Player physics process ran smoothly. Speed: ", game.player.current_speed)
	if game.score_mgr.score <= 0:
		printerr("FAIL: Score did not increment over survival time")
		quit(1)
		return
	print("PASS: Survival scoring dynamic integration confirmed. Score = ", game.score_mgr.score)

	# 5. Test HUD Updates
	var hud_score_text = game.hud.score_label.text
	if int(hud_score_text) <= 0:
		printerr("FAIL: HUD score label did not update properly: ", hud_score_text)
		quit(1)
		return
	print("PASS: HUD real-time score display verified: ", hud_score_text)

	# 6. Test Level Completion Flow
	game.level_mgr.trigger_completion()
	await process_frame
	await process_frame

	if not game.hud.win_modal.visible:
		printerr("FAIL: Level Complete win modal was not shown on completion")
		quit(1)
		return
	print("PASS: Level Complete modal triggered and verified. Stars: ", game.hud.win_stars_label.text)

	# 7. Test SafeZone for Extraction Mission
	game._start_game(5) # Level 5 has REACH_SAFE_ZONE objective
	await process_frame
	await process_frame

	if not is_instance_valid(game.active_safe_zone):
		printerr("FAIL: SafeZone beacon was not spawned for extraction mission")
		quit(1)
		return
	print("PASS: Extraction SafeZone beacon spawned at ", game.active_safe_zone.position)

	print("=== ALL FULL GAME INTEGRATION TESTS PASSED SUCCESSFULLY ===")
	quit(0)
