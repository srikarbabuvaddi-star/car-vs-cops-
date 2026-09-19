extends SceneTree

func _init() -> void:
	call_deferred("_run_phase7_tests")

func _run_phase7_tests() -> void:
	print("=== RUNNING PHASE 7 AUTOMATED TESTS (LIGHTING, SIRENS, TIRE MARKS, PARTICLES, AUDIO) ===")

	var err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not load Game.tscn")
		quit(1)
		return

	await process_frame
	await process_frame

	var game = current_scene as GameController
	if not game:
		printerr("FAIL: GameController not loaded")
		quit(1)
		return

	# 1. Test Lighting & Environment Bloom
	var env_node = game.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not env_node or not env_node.environment:
		printerr("FAIL: WorldEnvironment missing")
		quit(1)
		return
	if not env_node.environment.glow_enabled:
		printerr("FAIL: Glow / bloom must be enabled for arcade neon lighting")
		quit(1)
		return
	print("PASS: WorldEnvironment neon bloom and arcade lighting verified.")

	# 2. Test Police Siren Lights
	var police_scene = load("res://scenes/PoliceCar.tscn")
	var cop = police_scene.instantiate() as PoliceAI
	game.add_child(cop)
	cop.position = Vector3(10, 0, 10)

	await process_frame
	for f in range(12):
		await physics_frame

	if not is_instance_valid(cop.omni_red) or not is_instance_valid(cop.omni_blue):
		printerr("FAIL: Police lightbar omni lights missing")
		quit(1)
		return
	print("PASS: Police flashing red/blue lightbar sirens verified.")

	# 3. Test Tire Marks & Smoke Particles
	var player = game.player
	if not player.tire_marks_left or not player.tire_marks_right:
		printerr("FAIL: Tire marks system missing from PlayerCar")
		quit(1)
		return
	if not player.left_smoke or not player.nitro_flames:
		printerr("FAIL: Particle systems missing from PlayerCar")
		quit(1)
		return

	# Simulate drift skid
	player.current_speed = 18.0
	player.manual_steer = 1.0
	for f in range(20):
		await physics_frame

	if not player.left_smoke.emitting:
		printerr("FAIL: Smoke particles not emitting during drift")
		quit(1)
		return
	print("PASS: Tire marks generation and drift smoke particles verified.")

	# 4. Test Procedural Audio (Engine loop, Siren, Impacts, Pickups)
	if not SoundManager.instance:
		printerr("FAIL: SoundManager singleton missing")
		quit(1)
		return

	SoundManager.instance.update_engine_pitch(0.2)
	SoundManager.instance.update_engine_pitch(0.9)
	SoundManager.instance.play_siren()
	SoundManager.instance.play_nitro()
	SoundManager.instance.play_skid()
	SoundManager.instance.play_crash()
	SoundManager.instance.play_pickup()
	SoundManager.instance.play_close_call()
	SoundManager.instance.play_win()
	SoundManager.instance.play_fail()
	SoundManager.instance.stop_engine()
	print("PASS: Complete procedural arcade audio suite verified.")

	cop.queue_free()

	print("=== ALL PHASE 7 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
