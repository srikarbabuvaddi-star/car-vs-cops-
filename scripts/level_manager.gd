class_name LevelManager
extends Node

signal level_started(config: LevelConfig)
signal objective_progress(current_val: float, target_val: float, display_str: String)
signal level_completed(stars: int, final_score: int, elapsed_time: float)
signal level_failed(final_score: int, elapsed_time: float)

@export var current_level_number: int = 1

var current_config: LevelConfig
var elapsed_time: float = 0.0
var distance_traveled: float = 0.0
var pickups_collected: int = 0
var escapes_count: int = 0
var safe_zone_reached: bool = false
var is_game_active: bool = false
var initial_player_pos: Vector3 = Vector3.ZERO
var last_player_pos: Vector3 = Vector3.ZERO

# References to other game components
var player: PlayerController
var spawner: PoliceSpawner
var heat_mgr: HeatManager
var score_mgr: ScoreManager
var arena: GridArena

func _ready() -> void:
	SaveManager.ensure_loaded()

func start_level(lvl: int) -> void:
	current_level_number = clamp(lvl, 1, 100)
	current_config = LevelConfig.generate_level(current_level_number)

	elapsed_time = 0.0
	distance_traveled = 0.0
	pickups_collected = 0
	escapes_count = 0
	safe_zone_reached = false
	is_game_active = true

	# Wire up player
	if is_instance_valid(player):
		player.global_position = Vector3.ZERO
		player.current_speed = 0.0
		player.lives = 3
		initial_player_pos = player.global_position
		last_player_pos = initial_player_pos

	# Configure spawner
	if is_instance_valid(spawner):
		spawner.max_active_cops = current_config.max_police_count
		spawner.speed_multiplier = current_config.police_speed_multiplier
		spawner.base_spawn_interval = current_config.spawn_interval
		spawner.interceptor_chance = current_config.interceptor_probability
		spawner.blocker_chance = current_config.blocker_probability

	# Configure arena
	if is_instance_valid(arena):
		arena.setup_arena(current_config.arena_size)

	level_started.emit(current_config)

func _process(delta: float) -> void:
	if not is_game_active or not current_config:
		return

	elapsed_time += delta

	# Track distance
	if is_instance_valid(player):
		var cur_pos = player.global_position
		var d = cur_pos.distance_to(last_player_pos)
		if d < 10.0: # Filter out sudden teleports
			distance_traveled += d
		last_player_pos = cur_pos

		# Check player death
		if player.lives <= 0:
			trigger_failure()
			return

	# Update objective feedback & check completion
	_check_objective_status()

func _check_objective_status() -> void:
	var current_val: float = 0.0
	var target_val: float = 1.0
	var label: String = ""

	match current_config.objective_type:
		LevelConfig.ObjectiveType.SURVIVE_TIME:
			current_val = elapsed_time
			target_val = current_config.target_survival_time
			label = "SURVIVE: %02d:%02d / %02d:%02d" % [
				int(current_val) / 60, int(current_val) % 60,
				int(target_val) / 60, int(target_val) % 60
			]
			if current_val >= target_val:
				trigger_completion()

		LevelConfig.ObjectiveType.TARGET_DISTANCE:
			current_val = distance_traveled
			target_val = current_config.target_distance
			label = "DISTANCE: %dm / %dm" % [int(current_val), int(target_val)]
			if current_val >= target_val:
				trigger_completion()

		LevelConfig.ObjectiveType.COLLECT_PICKUPS:
			current_val = float(pickups_collected)
			target_val = float(current_config.target_pickups)
			label = "ENERGY CELLS: %d / %d" % [int(current_val), int(target_val)]
			if current_val >= target_val:
				trigger_completion()

		LevelConfig.ObjectiveType.ESCAPE_POLICE:
			current_val = float(escapes_count)
			target_val = float(current_config.target_escapes)
			label = "ESCAPES: %d / %d" % [int(current_val), int(target_val)]
			if current_val >= target_val:
				trigger_completion()

		LevelConfig.ObjectiveType.REACH_SAFE_ZONE:
			current_val = 1.0 if safe_zone_reached else 0.0
			target_val = 1.0
			label = "REACH EXTRACTION ZONE"
			if safe_zone_reached:
				trigger_completion()

	objective_progress.emit(current_val, target_val, label)

func register_pickup_collected() -> void:
	pickups_collected += 1

func register_escape() -> void:
	escapes_count += 1

func register_safe_zone_entered() -> void:
	safe_zone_reached = true

func trigger_completion() -> void:
	if not is_game_active:
		return
	is_game_active = false

	var final_pts = score_mgr.score if is_instance_valid(score_mgr) else 5000

	# 3-Star Rating Calculation
	var stars = 1 # 1 star for beating level
	# 2nd Star: under target time or exceeded distance
	if elapsed_time <= current_config.target_survival_time * 1.2:
		stars += 1
	# 3rd Star: remaining lives or high close calls
	if is_instance_valid(player) and player.lives == 3:
		stars += 1
	elif is_instance_valid(score_mgr) and score_mgr.total_close_calls >= 2:
		stars += 1

	stars = clamp(stars, 1, 3)

	# Save progress
	SaveManager.record_level_completion(current_level_number, final_pts, elapsed_time, stars)

	level_completed.emit(stars, final_pts, elapsed_time)

func trigger_failure() -> void:
	if not is_game_active:
		return
	is_game_active = false
	var final_pts = score_mgr.score if is_instance_valid(score_mgr) else 0
	level_failed.emit(final_pts, elapsed_time)
