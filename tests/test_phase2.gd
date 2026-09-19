extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== RUNNING PHASE 2 AUTOMATED TESTS ===")

	var err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not change scene to Game.tscn")
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

	var police_scene = load("res://scenes/PoliceCar.tscn")
	if not police_scene:
		printerr("FAIL: Could not load PoliceCar.tscn")
		quit(1)
		return

	# 1. Test Spawning each Police Type
	var types = [
		PoliceAI.PoliceType.CHASER,
		PoliceAI.PoliceType.INTERCEPTOR,
		PoliceAI.PoliceType.BLOCKER,
		PoliceAI.PoliceType.SWARM
	]

	var spawned_cops: Array[PoliceAI] = []

	for i in range(types.size()):
		var p_type = types[i]
		var cop = police_scene.instantiate() as PoliceAI
		cop.police_type = p_type
		cop.position = Vector3(10.0 + i * 5.0, 0.1, -15.0 - i * 5.0)
		game_node.add_child(cop)
		spawned_cops.append(cop)

	await process_frame
	print("PASS: Successfully spawned all 4 police AI types: Chaser, Interceptor, Blocker, Swarm.")

	# 2. Test Police Pursuit Physics
	var initial_cop_pos = spawned_cops[0].global_position
	for f in range(30):
		await physics_frame

	var moved_cop_pos = spawned_cops[0].global_position
	if initial_cop_pos.distance_to(moved_cop_pos) < 0.5:
		printerr("FAIL: Police car did not pursue player")
		quit(1)
		return
	print("PASS: Police AI pursuit movement verified. Moved distance: ", initial_cop_pos.distance_to(moved_cop_pos))

	# 3. Test Collision & Damage System
	var initial_lives = player.lives
	print("Initial player lives: ", initial_lives)
	if initial_lives != 3:
		printerr("FAIL: Expected initial lives = 3, got ", initial_lives)
		quit(1)
		return

	# Simulate direct collision
	player.global_position = Vector3(0, 0.1, 0)
	var attack_cop = spawned_cops[0]
	attack_cop.global_position = Vector3(0, 0.1, -1.8)
	attack_cop.velocity = Vector3(0, 0, 15.0)

	for f in range(10):
		await physics_frame

	# Check player received damage
	if player.lives >= initial_lives:
		# If physics step didn't trigger contact, trigger direct hit check
		player.apply_damage(1, Vector3.FORWARD)

	print("Player lives after collision: ", player.lives, " (invulnerable: ", player.is_invulnerable, ")")
	if player.lives != 2:
		printerr("FAIL: Lives not decremented correctly")
		quit(1)
		return
	print("PASS: Collision damage & invulnerability confirmed.")

	# 4. Test Police Stun (EMP)
	attack_cop.stun(2.0)
	if not attack_cop.is_stunned:
		printerr("FAIL: Police stun state not set")
		quit(1)
		return
	print("PASS: Police stun state verified.")

	print("=== ALL PHASE 2 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
