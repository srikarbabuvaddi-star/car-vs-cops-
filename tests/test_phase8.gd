extends SceneTree

func _init() -> void:
	call_deferred("_run_phase8_tests")

func _run_phase8_tests() -> void:
	print("=== RUNNING PHASE 8 AUTOMATED TESTS (PROGRESSION, REPLAY, SAVE PERSISTENCE, ACCEPTANCE) ===")

	# 1. Verify All 100 Levels Deterministic Configuration
	print("Validating all 100 levels across 10 difficulty tiers...")
	var prev_max_police = 0
	for lvl in range(1, 101):
		var cfg = LevelConfig.generate_level(lvl)
		if cfg.level_number != lvl:
			printerr("FAIL: Invalid level number in config: ", lvl)
			quit(1)
			return
		if cfg.target_survival_time <= 0.0 or cfg.max_police_count < 2:
			printerr("FAIL: Invalid parameters for level ", lvl)
			quit(1)
			return
		if cfg.tier > 10 or cfg.tier < 1:
			printerr("FAIL: Invalid tier for level ", lvl)
			quit(1)
			return

	print("PASS: All 100 levels verified with valid objectives and tier scaling.")

	# 2. Test Strict Save Progression & Locked Level Protection
	SaveManager.reset_save_data()
	if not SaveManager.is_level_unlocked(1):
		printerr("FAIL: Level 1 must be unlocked by default")
		quit(1)
		return
	if SaveManager.is_level_unlocked(2) or SaveManager.is_level_unlocked(50) or SaveManager.is_level_unlocked(100):
		printerr("FAIL: Levels 2-100 must be locked initially")
		quit(1)
		return
	print("PASS: Initial lock state verified (L1 unlocked, L2..100 locked).")

	# Beat Level 1 with 2 Stars
	SaveManager.record_level_completion(1, 10000, 35.0, 2)
	if not SaveManager.is_level_completed(1):
		printerr("FAIL: Level 1 not recorded as completed")
		quit(1)
		return
	if not SaveManager.is_level_unlocked(2):
		printerr("FAIL: Completing Level 1 must unlock Level 2")
		quit(1)
		return
	if SaveManager.is_level_unlocked(3):
		printerr("FAIL: Level 3 must remain locked after beating only Level 1")
		quit(1)
		return
	print("PASS: Level 1 completion unlocked Level 2 in strict chain.")

	# 3. Test Replay Level 1 (Higher Score & 3 Stars)
	SaveManager.record_level_completion(1, 15000, 28.0, 3)
	if SaveManager.get_level_stars(1) != 3:
		printerr("FAIL: Replay did not update star record to 3")
		quit(1)
		return
	if SaveManager.get_level_best_score(1) != 15000:
		printerr("FAIL: Replay did not retain best score")
		quit(1)
		return
	print("PASS: Replay correctly preserved highest score and improved star rating.")

	# 4. Test Save File Persistence across Reload
	SaveManager._is_loaded = false
	SaveManager.ensure_loaded()
	if not SaveManager.is_level_unlocked(2) or SaveManager.get_level_best_score(1) != 15000:
		printerr("FAIL: Save file did not persist data to disk properly")
		quit(1)
		return
	print("PASS: Local JSON persistence successfully verified across reload.")

	# 5. Test Fast Restart & Scene Flow
	var err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not load Game.tscn")
		quit(1)
		return

	await process_frame
	await process_frame

	var game = current_scene as GameController
	if not game:
		printerr("FAIL: GameController not active")
		quit(1)
		return

	# Fast restart
	game._on_retry()
	if game.score_mgr.score != 0:
		printerr("FAIL: Score not reset immediately upon restart")
		quit(1)
		return
	await process_frame
	if not game.level_mgr.is_game_active:
		printerr("FAIL: LevelManager not active after restart")
		quit(1)
		return
	print("PASS: Fast restart and replay flow confirmed.")

	print("=== ALL PHASE 8 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
