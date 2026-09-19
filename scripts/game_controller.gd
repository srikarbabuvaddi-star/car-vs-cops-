class_name GameController
extends Node3D

@export var default_level: int = 1

var level_mgr: LevelManager
var score_mgr: ScoreManager
var heat_mgr: HeatManager
var spawner: PoliceSpawner
var pickup_mgr: PickupManager
var arena: GridArena
var player: PlayerController
var hud: HUD
var active_safe_zone: SafeZone

var is_paused: bool = false
var _current_level: int = 1

func _ready() -> void:
	SaveManager.ensure_loaded()
	_ensure_sound_manager()
	_resolve_scene_nodes()
	_wire_signals()

	var target_lvl = int(SaveManager.data.get("target_level", SaveManager.data.get("highest_unlocked_level", 1)))
	if target_lvl <= 0:
		target_lvl = default_level
	_start_game(target_lvl)

func _ensure_sound_manager() -> void:
	if not SoundManager.instance:
		var sm = SoundManager.new()
		get_tree().root.add_child.call_deferred(sm)

func _resolve_scene_nodes() -> void:
	player = get_node_or_null("PlayerCar") as PlayerController
	arena = get_node_or_null("GridArena") as GridArena

	# Find or instantiate managers
	score_mgr = get_node_or_null("ScoreManager") as ScoreManager
	if not score_mgr:
		score_mgr = ScoreManager.new()
		score_mgr.name = "ScoreManager"
		add_child(score_mgr)
	score_mgr.add_to_group("score_manager")

	heat_mgr = get_node_or_null("HeatManager") as HeatManager
	if not heat_mgr:
		heat_mgr = HeatManager.new()
		heat_mgr.name = "HeatManager"
		add_child(heat_mgr)
	heat_mgr.add_to_group("heat_manager")

	spawner = get_node_or_null("PoliceSpawner") as PoliceSpawner
	if not spawner:
		spawner = PoliceSpawner.new()
		spawner.name = "PoliceSpawner"
		add_child(spawner)
	spawner.heat_manager = heat_mgr

	pickup_mgr = get_node_or_null("PickupManager") as PickupManager
	if not pickup_mgr:
		pickup_mgr = PickupManager.new()
		pickup_mgr.name = "PickupManager"
		add_child(pickup_mgr)

	level_mgr = get_node_or_null("LevelManager") as LevelManager
	if not level_mgr:
		level_mgr = LevelManager.new()
		level_mgr.name = "LevelManager"
		add_child(level_mgr)
	level_mgr.add_to_group("level_manager")

	# HUD
	hud = get_node_or_null("HUD") as HUD
	if not hud:
		var hud_scene = load("res://scenes/HUD.tscn")
		if hud_scene:
			hud = hud_scene.instantiate() as HUD
			add_child(hud)

	# Wire level manager references
	level_mgr.player = player
	level_mgr.spawner = spawner
	level_mgr.heat_mgr = heat_mgr
	level_mgr.score_mgr = score_mgr
	level_mgr.arena = arena

func _wire_signals() -> void:
	if is_instance_valid(level_mgr):
		level_mgr.level_started.connect(_on_level_started)
		level_mgr.objective_progress.connect(_on_objective_progress)
		level_mgr.level_completed.connect(_on_level_completed)
		level_mgr.level_failed.connect(_on_level_failed)

	if is_instance_valid(score_mgr) and is_instance_valid(hud):
		score_mgr.score_updated.connect(hud.update_score)
		score_mgr.combo_updated.connect(hud.update_combo)
		score_mgr.combo_broken.connect(hud.notify_combo_broken)

	if is_instance_valid(heat_mgr) and is_instance_valid(hud):
		heat_mgr.heat_changed.connect(hud.update_heat)

	if is_instance_valid(player):
		if is_instance_valid(hud):
			player.nitro_changed.connect(hud.update_nitro)
			player.speed_changed.connect(func(spd, max_s):
				hud.update_speed(spd)
				if SoundManager.instance:
					var is_nitro = player.is_nitro_active if is_instance_valid(player) else false
					SoundManager.instance.update_engine_pitch(spd / max(1.0, max_s), is_nitro)
			)
			player.life_lost.connect(_on_player_life_lost)
			player.close_call_triggered.connect(_on_close_call)

	if is_instance_valid(hud):
		hud.next_level_pressed.connect(_on_next_level)
		hud.retry_pressed.connect(_on_retry)
		hud.level_select_pressed.connect(_on_level_select)
		hud.main_menu_pressed.connect(_on_main_menu)
		hud.resume_pressed.connect(_toggle_pause)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()

	# Dynamic Police Siren Management (Wail vs Yelp)
	if is_instance_valid(level_mgr) and level_mgr.is_game_active and SoundManager.instance:
		var cops = get_tree().get_nodes_in_group("police")
		if cops.size() > 0:
			var min_dist = 999.0
			if is_instance_valid(player):
				for cop in cops:
					if is_instance_valid(cop) and cop is Node3D:
						var d = player.global_position.distance_to((cop as Node3D).global_position)
						if d < min_dist:
							min_dist = d
			var is_urgent = min_dist < 18.0
			SoundManager.instance.play_siren(is_urgent)
		else:
			SoundManager.instance.stop_siren()

	# Survival score progression & HUD time
	if is_instance_valid(level_mgr) and level_mgr.is_game_active:
		if is_instance_valid(hud):
			hud.update_elapsed_time(level_mgr.elapsed_time)
			hud.set_energy_pickups(level_mgr.pickups_collected)

			# Destination compass pointer & distance
			if is_instance_valid(player) and is_instance_valid(active_safe_zone):
				var to_dest = active_safe_zone.global_position - player.global_position
				var dist = to_dest.length()
				var car_forward = -player.global_transform.basis.z.normalized()
				var angle_diff = car_forward.signed_angle_to(to_dest.normalized(), Vector3.UP)
				var arrow = "▲"
				if angle_diff > 2.35 or angle_diff < -2.35:
					arrow = "▼"
				elif angle_diff > 1.57:
					arrow = "▶"
				elif angle_diff > 0.78:
					arrow = "↗"
				elif angle_diff < -1.57:
					arrow = "◀"
				elif angle_diff < -0.78:
					arrow = "↖"
				hud.update_destination_info(dist, arrow)

		if is_instance_valid(score_mgr) and is_instance_valid(player):
			var is_fast = abs(player.current_speed) > 18.0
			score_mgr.add_survival_score(delta, is_fast)

		if is_instance_valid(heat_mgr):
			var heat_mult = 1.0
			if level_mgr.current_config:
				heat_mult = level_mgr.current_config.heat_increase_rate
			heat_mgr.process_survival(delta, heat_mult)

func _start_game(lvl: int) -> void:
	get_tree().paused = false
	is_paused = false
	_current_level = lvl
	SaveManager.data["target_level"] = lvl

	# Clean up any leftover police or pickups
	for cop in get_tree().get_nodes_in_group("police"):
		cop.queue_free()
	for pk in get_tree().get_nodes_in_group("pickups"):
		pk.queue_free()
	if is_instance_valid(active_safe_zone):
		active_safe_zone.queue_free()

	if is_instance_valid(score_mgr):
		score_mgr.reset_score()
	if is_instance_valid(heat_mgr):
		heat_mgr.current_heat = 1
		heat_mgr.heat_exp = 0.0
	if is_instance_valid(hud):
		hud._hide_modals()

	level_mgr.start_level(_current_level)

func _on_level_started(config: LevelConfig) -> void:
	if is_instance_valid(hud):
		hud.set_level_info(config.level_number, config.world_title)
		hud.update_lives(player.lives if is_instance_valid(player) else 3)
		hud.update_shield(player.has_shield if is_instance_valid(player) else false)

	# Always spawn prominent destination endpoint on every level
	_spawn_safe_zone(config.arena_size)

func _spawn_safe_zone(arena_size: float) -> void:
	var safe_scene = load("res://scenes/SafeZone.tscn")
	if not safe_scene:
		return
	active_safe_zone = safe_scene.instantiate() as SafeZone
	var bound = arena_size * 0.38
	var rand_x = randf_range(-bound, bound)
	var rand_z = randf_range(-bound, bound)
	if Vector2(rand_x, rand_z).length() < 35.0:
		rand_x += (45.0 if rand_x >= 0.0 else -45.0)
	active_safe_zone.position = Vector3(rand_x, 0.0, rand_z)
	add_child(active_safe_zone)

	if is_instance_valid(hud) and is_instance_valid(hud.minimap):
		hud.minimap.destination = active_safe_zone
		hud.minimap.arena_world_radius = arena_size * 0.5

func _on_objective_progress(cur_val: float, target_val: float, label_str: String) -> void:
	if is_instance_valid(hud):
		hud.update_objective_progress(cur_val, target_val, label_str)

func _on_level_completed(stars: int, final_score: int, elapsed_time: float) -> void:
	if SoundManager.instance:
		SoundManager.instance.stop_engine()
		SoundManager.instance.stop_siren()
		SoundManager.instance.play_win()
	get_tree().paused = true
	if is_instance_valid(hud):
		var has_next = _current_level < 100
		var close_calls = score_mgr.total_close_calls if is_instance_valid(score_mgr) else 0
		var best_score = SaveManager.get_level_best_score(_current_level)
		hud.show_win_modal(stars, final_score, elapsed_time, close_calls, best_score, has_next)

func _on_level_failed(final_score: int, elapsed_time: float) -> void:
	if SoundManager.instance:
		SoundManager.instance.stop_all()
		SoundManager.instance.play_fail()
	# Stop player and all cops
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
	for cop in get_tree().get_nodes_in_group("police"):
		if is_instance_valid(cop) and cop is CharacterBody3D:
			cop.velocity = Vector3.ZERO
	get_tree().paused = true
	if is_instance_valid(hud):
		var close_calls = score_mgr.total_close_calls if is_instance_valid(score_mgr) else 0
		var best_score = SaveManager.get_level_best_score(_current_level)
		var max_heat = heat_mgr.current_heat if is_instance_valid(heat_mgr) else 1
		hud.show_fail_modal(final_score, elapsed_time, max_heat, close_calls, best_score)

func _on_player_life_lost(remaining_lives: int) -> void:
	if SoundManager.instance:
		SoundManager.instance.play_crash()
	if is_instance_valid(hud):
		hud.update_lives(remaining_lives)
		hud.update_shield(player.has_shield if is_instance_valid(player) else false)

func _on_close_call(_police_ref: Node3D) -> void:
	if SoundManager.instance:
		SoundManager.instance.play_close_call()
	if is_instance_valid(hud):
		hud.show_toast("CLOSE CALL!", Color(1.0, 0.85, 0.1))

func _on_next_level() -> void:
	get_tree().paused = false
	if _current_level < 100:
		_start_game(_current_level + 1)

func _on_retry() -> void:
	get_tree().paused = false
	_start_game(_current_level)

func _on_level_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _toggle_pause() -> void:
	if not is_instance_valid(level_mgr) or not level_mgr.is_game_active:
		return
	is_paused = !is_paused
	get_tree().paused = is_paused
	if is_instance_valid(hud):
		hud.show_pause_modal(is_paused)
