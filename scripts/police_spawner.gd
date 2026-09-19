class_name PoliceSpawner
extends Node3D

@export var police_scene: PackedScene
@export var min_spawn_radius: float = 38.0
@export var max_spawn_radius: float = 52.0
@export var base_spawn_interval: float = 3.5

# Configurable by LevelConfig & Heat
@export var max_active_cops: int = 4
@export var speed_multiplier: float = 1.0
@export var interceptor_chance: float = 0.25
@export var blocker_chance: float = 0.2

var spawn_timer: float = 0.0
var target_player: Node3D = null
var heat_manager: HeatManager = null

func _ready() -> void:
	if not police_scene:
		police_scene = preload("res://scenes/PoliceCar.tscn")
	target_player = get_tree().get_first_node_in_group("player") as Node3D

func _process(delta: float) -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node3D
		if not target_player:
			return

	_cleanup_distant_cops()

	spawn_timer += delta
	var dynamic_interval = max(1.2, base_spawn_interval - (get_current_heat() * 0.25))

	if spawn_timer >= dynamic_interval:
		spawn_timer = 0.0
		var active_count = get_active_police_count()
		var allowed_max = get_max_cops_for_heat()
		if active_count < allowed_max:
			spawn_police_car()

func get_current_heat() -> int:
	if is_instance_valid(heat_manager):
		return heat_manager.current_heat
	return 1

func get_max_cops_for_heat() -> int:
	var heat = get_current_heat()
	# Scales from 2 at Heat 1 up to max_active_cops at high heat
	return clamp(2 + int(heat * 0.8), 2, max_active_cops)

func get_active_police_count() -> int:
	return get_tree().get_nodes_in_group("police").size()

func spawn_police_car() -> PoliceAI:
	if not police_scene:
		return null

	var cop = police_scene.instantiate() as PoliceAI
	if not cop:
		return null

	var spawn_pos = _calculate_offscreen_spawn_pos()
	cop.speed_multiplier = speed_multiplier * (1.0 + (get_current_heat() - 1) * 0.06)

	# Determine archetype based on heat & chances
	var heat = get_current_heat()
	var r = randf()

	if heat >= 6 and r < 0.35:
		cop.police_type = PoliceAI.PoliceType.SWARM
		cop.swarm_angle_offset = randf_range(0.0, TAU)
	elif heat >= 5 and r < (0.35 + blocker_chance):
		cop.police_type = PoliceAI.PoliceType.BLOCKER
	elif heat >= 4 and r < (0.35 + blocker_chance + interceptor_chance):
		cop.police_type = PoliceAI.PoliceType.INTERCEPTOR
	else:
		cop.police_type = PoliceAI.PoliceType.CHASER

	get_parent().add_child(cop)
	cop.global_position = spawn_pos

	# Face towards player initially
	if is_instance_valid(target_player):
		var dir = (target_player.global_position - spawn_pos).normalized()
		cop.look_at(spawn_pos + dir, Vector3.UP)

	return cop

func _calculate_offscreen_spawn_pos() -> Vector3:
	var p_pos = target_player.global_position if is_instance_valid(target_player) else Vector3.ZERO
	var angle = randf_range(0.0, TAU)
	var radius = randf_range(min_spawn_radius, max_spawn_radius)

	# For blockers at high heat, favor spawning in front of player
	if randf() < 0.4 and is_instance_valid(target_player):
		var p_forward = -target_player.global_transform.basis.z.normalized()
		var base_angle = atan2(p_forward.z, p_forward.x)
		angle = base_angle + randf_range(-0.5, 0.5)

	var offset = Vector3(cos(angle), 0.0, sin(angle)) * radius
	var spawn_pos = p_pos + offset
	spawn_pos.y = 0.1
	return spawn_pos

func _cleanup_distant_cops() -> void:
	if not is_instance_valid(target_player):
		return
	var p_pos = target_player.global_position
	var cops = get_tree().get_nodes_in_group("police")
	for cop in cops:
		if is_instance_valid(cop) and cop is Node3D:
			var dist = cop.global_position.distance_to(p_pos)
			if dist > 110.0:
				cop.queue_free()
