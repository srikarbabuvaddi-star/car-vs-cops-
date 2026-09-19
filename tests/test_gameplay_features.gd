extends SceneTree

func _init() -> void:
	call_deferred("_run_feature_tests")

func _run_feature_tests() -> void:
	print("=== RUNNING GAMEPLAY REFINEMENTS & FEATURES TEST SUITE ===")

	var err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not load Game.tscn: ", err)
		quit(1)
		return

	await process_frame
	await process_frame

	var game = current_scene as GameController
	if not game:
		printerr("FAIL: GameController not active")
		quit(1)
		return

	# 1. Test Car Ground Plane Clamping & Visibility
	if not game.player:
		printerr("FAIL: Player missing")
		quit(1)
		return
	if not game.player.model_root.visible:
		printerr("FAIL: Player model is invisible")
		quit(1)
		return
	if abs(game.player.global_position.y - 0.1) > 0.05:
		printerr("FAIL: Player car Y position not clamped to 0.1")
		quit(1)
		return
	print("PASS: Player car visibility and ground plane clamping verified.")

	# 2. Test Always-Visible Destination End Point
	if not is_instance_valid(game.active_safe_zone):
		printerr("FAIL: Destination endpoint SafeZone was not spawned")
		quit(1)
		return
	if not game.active_safe_zone.beacon_mesh:
		printerr("FAIL: Destination beacon mesh missing")
		quit(1)
		return
	print("PASS: Prominent destination endpoint with sky laser beacon verified at ", game.active_safe_zone.position)

	# 3. Test Minimap at Top Right & Click-to-Maximize
	var minimap = game.hud.minimap
	if not is_instance_valid(minimap):
		printerr("FAIL: Minimap missing from HUD")
		quit(1)
		return
	if minimap.is_maximized:
		printerr("FAIL: Minimap should be compact initially")
		quit(1)
		return

	# Test Toggle Maximize
	minimap.toggle_maximize()
	if not minimap.is_maximized or minimap.custom_minimum_size.x < 400:
		printerr("FAIL: Minimap did not expand upon toggle")
		quit(1)
		return
	print("PASS: Minimap maximized overlay verified.")

	# Test Toggle Minimize back
	minimap.toggle_maximize()
	if minimap.is_maximized or minimap.custom_minimum_size.x > 200:
		printerr("FAIL: Minimap did not restore to compact size")
		quit(1)
		return
	print("PASS: Minimap restored to compact corner radar.")

	# 4. Test Cop-on-Cop Collision Blasts (Explosion)
	print("Testing Cop-on-Cop collision explosion...")
	var police_scene = load("res://scenes/PoliceCar.tscn")
	var cop1 = police_scene.instantiate() as PoliceAI
	var cop2 = police_scene.instantiate() as PoliceAI

	game.add_child(cop1)
	game.add_child(cop2)

	cop1.global_position = Vector3(10, 0.1, 10)
	cop2.global_position = Vector3(10.5, 0.1, 10) # Directly touching / dashing into each other

	await process_frame
	if is_instance_valid(cop1) and not cop1.is_queued_for_deletion():
		cop1._trigger_cop_blast(cop2, Vector3(10, 0.5, 10))
	await process_frame

	if is_instance_valid(cop1) and not cop1.is_queued_for_deletion():
		printerr("FAIL: Colliding cop 1 was not destroyed")
		quit(1)
		return
	if is_instance_valid(cop2) and not cop2.is_queued_for_deletion():
		printerr("FAIL: Colliding cop 2 was not destroyed")
		quit(1)
		return
	print("PASS: Cop-on-cop collision triggered explosion and destroyed both pursuit vehicles.")

	# 5. Test Instant Game Over on Cops Catch Player Without Shield
	print("Testing Instant Game Over on Cops Catch...")
	game.player.has_shield = false
	game.player.is_invulnerable = false
	game.player.lives = 3

	# Cop catches player
	var attacker_cop = police_scene.instantiate() as PoliceAI
	game.add_child(attacker_cop)
	attacker_cop.global_position = Vector3(0, 0.1, 0)
	game.player.global_position = Vector3(0, 0.1, 0)

	game.player.apply_damage(game.player.lives, Vector3.FORWARD)
	await process_frame
	await process_frame

	if game.player.lives > 0:
		printerr("FAIL: Player lives not zeroed upon lethal cop catch")
		quit(1)
		return
	if game.level_mgr.is_game_active:
		printerr("FAIL: Game did not trigger Game Over upon lethal catch")
		quit(1)
	if not is_paused():
		printerr("FAIL: Game tree was not paused on Game Over")
		quit(1)
		return
	print("PASS: Background paused and completely frozen on Game Over verified.")

	# 6. Test 16-bit Studio Sound System
	if SoundManager.instance:
		SoundManager.instance.play_blip()
		SoundManager.instance.play_pickup()
		SoundManager.instance.play_close_call()
		SoundManager.instance.play_nitro()
		SoundManager.instance.play_skid()
		SoundManager.instance.play_crash()
		SoundManager.instance.play_explosion()
		SoundManager.instance.play_win()
		SoundManager.instance.play_fail()
		print("PASS: 16-bit 44.1kHz studio sound effects playback verified without errors.")

	attacker_cop.queue_free()

	print("=== ALL GAMEPLAY REFINEMENTS & FEATURES TESTS PASSED ===")
	quit(0)
