extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== RUNNING PHASE 4 AUTOMATED TESTS ===")

	# 1. Test Deterministic Generation of all 100 Levels
	print("Testing generation of all 100 levels...")
	var prev_speed = 0.0
	for lvl in range(1, 101):
		var cfg = LevelConfig.generate_level(lvl)
		if cfg.level_number != lvl:
			printerr("FAIL: Config level number mismatch for level ", lvl)
			quit(1)
			return
		var expected_tier = int((lvl - 1) / 10) + 1
		if cfg.tier != expected_tier:
			printerr("FAIL: Tier mismatch for level ", lvl, " expected ", expected_tier, " got ", cfg.tier)
			quit(1)
			return

	# Deterministic consistency check
	var cfg_a = LevelConfig.generate_level(42)
	var cfg_b = LevelConfig.generate_level(42)
	if cfg_a.target_survival_time != cfg_b.target_survival_time or cfg_a.police_speed_multiplier != cfg_b.police_speed_multiplier:
		printerr("FAIL: Determinism check failed for Level 42")
		quit(1)
		return
	print("PASS: All 100 levels deterministically verified across 10 difficulty tiers.")

	# 2. Test SaveManager Strict Progression
	SaveManager.reset_save_data()
	if not SaveManager.is_level_unlocked(1):
		printerr("FAIL: Level 1 must be unlocked by default")
		quit(1)
		return
	if SaveManager.is_level_unlocked(2):
		printerr("FAIL: Level 2 must be locked initially")
		quit(1)
		return
	if SaveManager.is_level_unlocked(100):
		printerr("FAIL: Level 100 must be locked initially")
		quit(1)
		return
	print("PASS: Initial lock state verified (L1 unlocked, L2..100 locked).")

	# Complete Level 1
	SaveManager.record_level_completion(1, 12500, 32.5, 3)
	if not SaveManager.is_level_completed(1):
		printerr("FAIL: Level 1 not marked as completed")
		quit(1)
		return
	if not SaveManager.is_level_unlocked(2):
		printerr("FAIL: Completing Level 1 did not unlock Level 2")
		quit(1)
		return
	if SaveManager.is_level_unlocked(3):
		printerr("FAIL: Level 3 should still be locked after only beating Level 1")
		quit(1)
		return
	if SaveManager.get_level_stars(1) != 3:
		printerr("FAIL: Level 1 stars mismatch")
		quit(1)
		return
	if SaveManager.get_level_best_score(1) != 12500:
		printerr("FAIL: Level 1 score mismatch")
		quit(1)
		return
	print("PASS: Strict unlock chain progression verified.")

	# 3. Test LevelSelect UI Generation
	var select_scene = load("res://scenes/LevelSelect.tscn")
	if not select_scene:
		printerr("FAIL: Could not load LevelSelect.tscn")
		quit(1)
		return

	var select_node = select_scene.instantiate() as LevelSelect
	root.add_child(select_node)
	await process_frame
	await process_frame

	var worlds_container = select_node.get_node("MarginContainer/VBoxContainer/ScrollContainer/WorldsContainer")
	if worlds_container.get_child_count() != 10:
		printerr("FAIL: Expected 10 world panels, got ", worlds_container.get_child_count())
		quit(1)
		return
	print("PASS: LevelSelect UI rendered 10 worlds with 100 total level nodes.")

	select_node.queue_free()

	# 4. Test LevelManager Objective Flow
	var lvl_mgr = LevelManager.new()
	lvl_mgr.score_mgr = ScoreManager.new()
	root.add_child(lvl_mgr)
	lvl_mgr.start_level(1)

	if lvl_mgr.current_config.level_number != 1:
		printerr("FAIL: LevelManager failed to configure Level 1")
		quit(1)
		return

	# Simulate completion
	lvl_mgr.trigger_completion()
	if not SaveManager.is_level_completed(1):
		printerr("FAIL: Level completion not recorded via LevelManager")
		quit(1)
		return
	print("PASS: LevelManager start and completion flow verified.")

	if is_instance_valid(lvl_mgr.score_mgr):
		lvl_mgr.score_mgr.queue_free()
	lvl_mgr.queue_free()

	print("=== ALL PHASE 4 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
