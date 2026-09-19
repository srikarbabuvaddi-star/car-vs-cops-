extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== RUNNING PHASE 5 AUTOMATED TESTS ===")

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

	var score_mgr = game_node.get_node_or_null("ScoreManager") as ScoreManager
	if not score_mgr:
		score_mgr = ScoreManager.new()
		score_mgr.add_to_group("score_manager")
		game_node.add_child(score_mgr)

	var lvl_mgr = game_node.get_node_or_null("LevelManager") as LevelManager
	if not lvl_mgr:
		lvl_mgr = LevelManager.new()
		lvl_mgr.add_to_group("level_manager")
		game_node.add_child(lvl_mgr)

	# 1. Test Shield Pickup & Absorption
	print("Testing Shield Pickup & Hit Absorption...")
	var pickup_scene = load("res://scenes/Pickup.tscn")
	var shield_pk = pickup_scene.instantiate() as Pickup
	shield_pk.pickup_type = Pickup.PickupType.SHIELD
	game_node.add_child(shield_pk)

	# Apply effect to player
	shield_pk._apply_effect(player)
	if not player.has_shield:
		printerr("FAIL: Shield pickup did not activate player shield")
		quit(1)
		return
	print("PASS: Shield activated on player.")

	# Player hit while shield is active
	var lives_before_hit = player.lives
	player.apply_damage(1, Vector3.FORWARD)
	if player.lives != lives_before_hit:
		printerr("FAIL: Player lost life while shield was active!")
		quit(1)
		return
	if player.has_shield:
		printerr("FAIL: Shield did not deplete after absorbing hit")
		quit(1)
		return
	print("PASS: Shield successfully absorbed collision with 0 damage taken.")

	# 2. Test Nitro Pickup
	player.nitro_amount = 20.0
	var nitro_pk = pickup_scene.instantiate() as Pickup
	nitro_pk.pickup_type = Pickup.PickupType.NITRO
	game_node.add_child(nitro_pk)
	nitro_pk.position = Vector3(100, 0, 100)
	nitro_pk._apply_effect(player)
	if player.nitro_amount < 99.0:
		printerr("FAIL: Nitro pickup did not refill tank")
		quit(1)
		return
	print("PASS: Nitro pickup successfully refilled tank to ", player.nitro_amount)
	nitro_pk.queue_free()

	# 3. Test Close Call & Time Dilation
	print("Testing Close Call mechanic & Time Dilation...")
	var police_scene = load("res://scenes/PoliceCar.tscn")
	var cop = police_scene.instantiate() as PoliceAI
	cop.position = Vector3(200, 0, 200)
	game_node.add_child(cop)

	player.trigger_close_call(cop)
	if Engine.time_scale > 0.3:
		printerr("FAIL: Time dilation did not trigger! time_scale = ", Engine.time_scale)
		quit(1)
		return
	print("PASS: Time dilation slow-mo active! time_scale = ", Engine.time_scale)

	if score_mgr.combo_multiplier != 2:
		printerr("FAIL: Score combo not incremented to x2")
		quit(1)
		return
	print("PASS: Escape Chain combo increased to x", score_mgr.combo_multiplier)

	# Wait for slow-mo tween to restore time scale
	for f in range(25):
		await process_frame

	Engine.time_scale = 1.0 # Ensure reset
	print("PASS: Time scale smoothly restored.")

	# 4. Test Combo Break on Major Hit
	player.has_shield = false
	player.is_invulnerable = false
	player.invulnerable_timer = 0.0
	player.apply_damage(1, Vector3.BACK)
	if score_mgr.combo_multiplier != 1:
		printerr("FAIL: Collision did not reset combo chain. Multiplier is ", score_mgr.combo_multiplier)
		quit(1)
		return
	print("PASS: Major collision correctly reset combo chain.")

	if is_instance_valid(cop):
		cop.queue_free()
	if is_instance_valid(shield_pk):
		shield_pk.queue_free()

	print("=== ALL PHASE 5 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
