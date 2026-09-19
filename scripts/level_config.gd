class_name LevelConfig
extends RefCounted

enum ObjectiveType {
	SURVIVE_TIME,
	TARGET_DISTANCE,
	ESCAPE_POLICE,
	COLLECT_PICKUPS,
	REACH_SAFE_ZONE
}

var level_number: int = 1
var tier: int = 1
var world_number: int = 1
var world_title: String = "FIRST ESCAPE"
var objective_type: ObjectiveType = ObjectiveType.SURVIVE_TIME

# Objectives & Targets
var target_survival_time: float = 30.0 # seconds
var target_distance: float = 300.0 # meters
var target_escapes: int = 5
var target_pickups: int = 6

# Police & Threat Parameters
var starting_police_count: int = 1
var max_police_count: int = 2
var police_speed_multiplier: float = 0.85
var police_aggression: float = 2.8
var spawn_interval: float = 4.5
var interceptor_probability: float = 0.0
var blocker_probability: float = 0.0
var swarm_probability: float = 0.0

# Environment & Progression
var obstacle_density: int = 4
var pickup_spawn_rate: float = 6.0
var heat_increase_rate: float = 0.8
var arena_size: float = 180.0
var safe_zone_count: int = 1

static func get_world_title(world_idx: int) -> String:
	match world_idx:
		1: return "FIRST ESCAPE"
		2: return "POLICE PRESSURE"
		3: return "THE INTERCEPT"
		4: return "HIGH PURSUIT"
		5: return "GRID LOCK"
		6: return "NIGHT SHIFT"
		7: return "REDLINE"
		8: return "SWARM PROTOCOL"
		9: return "APEX HUNTERS"
		10: return "FINAL CHASE"
		_: return "PURSUIT"

static func generate_level(lvl: int) -> LevelConfig:
	var cfg = LevelConfig.new()
	cfg.level_number = clamp(lvl, 1, 100)

	# 10 Tiers (1-10, 11-20, ... 91-100)
	cfg.tier = clamp(int((cfg.level_number - 1) / 10) + 1, 1, 10)
	cfg.world_number = cfg.tier
	cfg.world_title = get_world_title(cfg.world_number)

	# Deterministic seed per level as required: seed(level_number * 1000 + 49)
	var rng = RandomNumberGenerator.new()
	rng.seed = (cfg.level_number * 1000) + 49

	# Objective Assignment based on tier & level
	var sub_lvl = (cfg.level_number - 1) % 10 + 1
	if cfg.level_number == 100:
		cfg.objective_type = ObjectiveType.REACH_SAFE_ZONE
	elif sub_lvl == 10 or sub_lvl == 5:
		cfg.objective_type = ObjectiveType.REACH_SAFE_ZONE
	elif sub_lvl % 3 == 0:
		cfg.objective_type = ObjectiveType.COLLECT_PICKUPS
	elif sub_lvl % 2 == 0:
		cfg.objective_type = ObjectiveType.TARGET_DISTANCE
	else:
		cfg.objective_type = ObjectiveType.SURVIVE_TIME

	# Scaled parameters across Tiers
	var t = float(cfg.level_number - 1) / 99.0 # 0.0 to 1.0

	# Survival time scales from 25s (lvl 1) to 80s (lvl 100)
	cfg.target_survival_time = 25.0 + t * 55.0 + rng.randf_range(-3.0, 3.0)
	# Distance scales from 250m to 1200m
	cfg.target_distance = 250.0 + t * 950.0
	# Pickups target scales from 4 to 12
	cfg.target_pickups = 4 + int(t * 8)
	# Escapes target
	cfg.target_escapes = 4 + int(t * 12)

	# Police counts
	cfg.starting_police_count = clamp(1 + int(t * 4), 1, 5)
	cfg.max_police_count = clamp(2 + int(t * 6), 2, 9)

	# Police speed multiplier (0.85x up to 1.35x)
	cfg.police_speed_multiplier = 0.85 + (t * 0.45) + rng.randf_range(-0.02, 0.02)
	cfg.police_aggression = 2.8 + (t * 1.6)

	# Spawning interval (4.5s down to 1.8s)
	cfg.spawn_interval = max(1.8, 4.5 - (t * 2.5))

	# Archetype Probabilities based on tier
	if cfg.tier >= 8:
		cfg.swarm_probability = 0.4
		cfg.interceptor_probability = 0.35
		cfg.blocker_probability = 0.25
	elif cfg.tier >= 6:
		cfg.swarm_probability = 0.25
		cfg.interceptor_probability = 0.35
		cfg.blocker_probability = 0.25
	elif cfg.tier >= 4:
		cfg.interceptor_probability = 0.4
		cfg.blocker_probability = 0.25
	elif cfg.tier >= 3:
		cfg.interceptor_probability = 0.25
		cfg.blocker_probability = 0.15
	elif cfg.tier >= 2:
		cfg.interceptor_probability = 0.15

	# Arena and obstacles
	cfg.arena_size = 180.0 + (t * 60.0)
	cfg.obstacle_density = 4 + int(t * 14)
	cfg.pickup_spawn_rate = max(4.0, 7.5 - (t * 2.5))
	cfg.heat_increase_rate = 0.8 + (t * 0.7)

	return cfg
