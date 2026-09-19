extends SceneTree

func _init() -> void:
	call_deferred("_run_phase6_tests")

func _run_phase6_tests() -> void:
	print("=== RUNNING PHASE 6 AUTOMATED TESTS (HUD, MAIN MENU, MODALS, SETTINGS) ===")

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

	# Verify Section 19 buttons
	var play_btn = menu.get_node_or_null("Margin/VBox/MenuButtons/PlayButton") as Button
	var levels_btn = menu.get_node_or_null("Margin/VBox/MenuButtons/LevelsButton") as Button
	var garage_btn = menu.get_node_or_null("Margin/VBox/MenuButtons/GarageButton") as Button
	var settings_btn = menu.get_node_or_null("Margin/VBox/MenuButtons/SettingsButton") as Button
	var help_btn = menu.get_node_or_null("Margin/VBox/MenuButtons/HelpButton") as Button

	if not play_btn or not levels_btn or not garage_btn or not settings_btn or not help_btn:
		printerr("FAIL: MainMenu missing one of the required buttons")
		quit(1)
		return
	print("PASS: MainMenu verified with all Section 19 buttons.")

	# Verify Garage Modal
	garage_btn.emit_signal("pressed")
	if not menu.garage_modal.visible:
		printerr("FAIL: Garage modal did not open on button press")
		quit(1)
		return
	print("PASS: Garage & vehicle stats modal verified.")
	menu.btn_garage_close.emit_signal("pressed")

	# Verify Settings Modal
	settings_btn.emit_signal("pressed")
	if not menu.settings_modal.visible:
		printerr("FAIL: Settings modal did not open on button press")
		quit(1)
		return
	print("PASS: Settings modal verified.")
	menu.btn_settings_close.emit_signal("pressed")

	# 2. Test HUD Scene & Section 18 Layout
	err = change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		printerr("FAIL: Could not load Game.tscn: ", err)
		quit(1)
		return

	await process_frame
	await process_frame

	var game = current_scene as GameController
	if not game or not is_instance_valid(game.hud):
		printerr("FAIL: GameController or HUD not found in Game.tscn")
		quit(1)
		return

	var hud = game.hud
	# Top Left: Score
	if not hud.score_label:
		printerr("FAIL: Top Left score label missing")
		quit(1)
		return
	hud.update_score(15420, 1)
	if hud.score_label.text != "15420":
		printerr("FAIL: Score label text mismatch")
		quit(1)
		return
	print("PASS: Top Left Score display verified.")

	# Top Center: Integrity Hearts
	hud.update_lives(2)
	var hearts = hud.lives_container.get_children()
	if hearts.size() != 3 or (hearts[0] as Label).text != "♥" or (hearts[2] as Label).text != "♡":
		printerr("FAIL: Top Center 3-heart integrity meter display incorrect")
		quit(1)
		return
	print("PASS: Top Center 3-heart integrity meter verified.")

	# Top Right: Heat & Energy Counter
	hud.update_heat(3, 40.0, 100.0)
	hud.set_energy_pickups(5)
	if hud.heat_label.text != "HEAT 03" or hud.energy_label.text != "● 05":
		printerr("FAIL: Top Right Heat or Energy counter incorrect")
		quit(1)
		return
	print("PASS: Top Right Heat & Energy pickup counter verified.")

	# Bottom Left: Nitro progress bar
	hud.update_nitro(85.0, 100.0)
	if hud.nitro_bar.value < 84.0:
		printerr("FAIL: Bottom Left Nitro progress bar value mismatch")
		quit(1)
		return
	print("PASS: Bottom Left Nitro progress bar verified.")

	# Bottom Center: Alert Toast
	hud.show_toast("ESCAPE CHAIN x3")
	if hud.toast_label.text != "ESCAPE CHAIN x3":
		printerr("FAIL: Bottom Center toast alert text mismatch")
		quit(1)
		return
	print("PASS: Bottom Center dynamic alert toast verified.")

	# Bottom Right: Speed & Time
	hud.update_speed(25.0) # ~ 90 KM/H
	hud.update_elapsed_time(84.0) # 01:24
	if not hud.speed_label.text.contains("KM/H") or hud.time_label.text != "01:24":
		printerr("FAIL: Bottom Right speed or time display incorrect: ", hud.speed_label.text, " ", hud.time_label.text)
		quit(1)
		return
	print("PASS: Bottom Right Speedometer & Survival Time display verified.")

	# 3. Test Modals: Level Complete & Game Over
	hud.show_win_modal(3, 18500, 45.2, 6, 20000, true)
	if not hud.win_modal.visible or not hud.win_stars_label.text.contains("★"):
		printerr("FAIL: Level Complete win modal display failed")
		quit(1)
		return
	print("PASS: Level Complete modal with stars, score, and close calls verified.")

	hud.show_fail_modal(9200, 32.0, 4, 3, 14000)
	if not hud.fail_modal.visible or not hud.fail_heat_label.text.contains("04"):
		printerr("FAIL: Game Over fail modal display failed")
		quit(1)
		return
	print("PASS: Game Over fail modal with survival statistics verified.")

	print("=== ALL PHASE 6 TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
