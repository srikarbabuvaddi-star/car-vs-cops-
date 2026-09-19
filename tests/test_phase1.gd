extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== RUNNING PHASE 1 AUTOMATED TESTS ===")
	
	var err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not change scene to Game.tscn: ", err)
		quit(1)
		return

	# Wait a couple of frames for the scene to properly enter the tree
	await process_frame
	await process_frame

	var game_node = current_scene
	if not game_node:
		printerr("FAIL: current_scene is null")
		quit(1)
		return
	print("PASS: Game.tscn active in SceneTree.")

	var player = game_node.get_node_or_null("PlayerCar") as PlayerController
	if not player:
		printerr("FAIL: PlayerCar not found")
		quit(1)
		return
	print("PASS: PlayerCar located.")

	var camera = game_node.get_node_or_null("Camera3D") as CameraFollow
	if not camera:
		printerr("FAIL: Camera3D not found")
		quit(1)
		return
	print("PASS: Camera3D located.")

	var arena = game_node.get_node_or_null("GridArena") as GridArena
	if not arena:
		printerr("FAIL: GridArena not found")
		quit(1)
		return
	print("PASS: GridArena initialized.")

	var initial_pos = player.global_position
	# Apply forward speed
	player.current_speed = 18.0

	# Process physics frames
	for i in range(30):
		await physics_frame

	var new_pos = player.global_position
	print("PASS: Car moved from ", initial_pos, " to ", new_pos)
	if new_pos.distance_to(initial_pos) < 1.0:
		printerr("FAIL: Car did not move sufficiently: dist = ", new_pos.distance_to(initial_pos))
		quit(1)
		return

	# Test steering & rotation
	var initial_rot = player.rotation.y
	player.rotate_y(0.5)
	if player.rotation.y == initial_rot:
		printerr("FAIL: Car rotation failed")
		quit(1)
		return
	print("PASS: Car steering rotation verified.")

	# Test nitro
	player.manual_forward = 1.0
	player.nitro_amount = 80.0
	player.manual_nitro = true
	for i in range(15):
		await physics_frame

	if player.nitro_amount >= 80.0:
		printerr("FAIL: Nitro did not drain while active")
		quit(1)
		return
	print("PASS: Nitro boost active and drained. Remaining: ", player.nitro_amount)

	print("=== ALL PHASE 1 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
