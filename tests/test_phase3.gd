extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== RUNNING PHASE 3 AUTOMATED TESTS ===")

	var err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not load Game.tscn")
		quit(1)
		return

	await process_frame
	await process_frame

	var game_node = current_scene
	var player = game_node.get_node_or_null("PlayerCar") as PlayerController
	if not player:
		printerr("FAIL: PlayerCar not found")
		quit(1)
		return

	# 1. Test HeatManager
	var heat_mgr = HeatManager.new()
	game_node.add_child(heat_mgr)
	if heat_mgr.current_heat != 1:
		printerr("FAIL: Initial heat should be 1, got ", heat_mgr.current_heat)
		quit(1)
		return
	print("PASS: HeatManager initialized at Heat 1.")

	heat_mgr.add_heat_exp(120.0)
	if heat_mgr.current_heat < 2:
		printerr("FAIL: Heat did not advance to Heat 2 after 120 EXP")
		quit(1)
		return
	print("PASS: Heat advanced to Heat ", heat_mgr.current_heat)

	# 2. Test ScoreManager & Escape Chain
	var score_mgr = ScoreManager.new()
	game_node.add_child(score_mgr)

	score_mgr.add_survival_score(1.0, false)
	if score_mgr.score <= 0:
		printerr("FAIL: Score did not increase on survival")
		quit(1)
		return
	print("PASS: Survival score incremented: ", score_mgr.score)

	score_mgr.register_close_call()
	if score_mgr.combo_multiplier != 2:
		printerr("FAIL: Expected combo multiplier 2 after close call, got ", score_mgr.combo_multiplier)
		quit(1)
		return
	print("PASS: Close Call combo increased to x", score_mgr.combo_multiplier)

	score_mgr.register_close_call()
	if score_mgr.combo_multiplier != 3:
		printerr("FAIL: Expected combo multiplier 3, got ", score_mgr.combo_multiplier)
		quit(1)
		return
	print("PASS: Close Call combo increased to x", score_mgr.combo_multiplier)

	# 3. Test PoliceSpawner
	var spawner = PoliceSpawner.new()
	spawner.heat_manager = heat_mgr
	spawner.max_active_cops = 5
	game_node.add_child(spawner)

	var cop1 = spawner.spawn_police_car()
	if not cop1:
		printerr("FAIL: PoliceSpawner failed to instantiate police car")
		quit(1)
		return

	var spawn_dist = cop1.global_position.distance_to(player.global_position)
	print("PASS: Police spawned at distance: ", spawn_dist)
	if spawn_dist < 30.0:
		printerr("FAIL: Police spawned too close to player! dist = ", spawn_dist)
		quit(1)
		return

	# Test distant despawn
	cop1.global_position = Vector3(500, 0, 500)
	spawner._cleanup_distant_cops()
	await process_frame
	if is_instance_valid(cop1) and not cop1.is_queued_for_deletion():
		printerr("FAIL: Distant police car was not cleaned up")
		quit(1)
		return
	print("PASS: Distant police car correctly cleaned up.")

	print("=== ALL PHASE 3 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
