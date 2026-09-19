class_name PickupManager
extends Node3D

@export var pickup_scene: PackedScene
@export var max_active_pickups: int = 5
@export var spawn_interval: float = 4.0
@export var arena_boundary: float = 75.0

var _timer: float = 0.0

func _ready() -> void:
	if not pickup_scene:
		pickup_scene = preload("res://scenes/Pickup.tscn")

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		var current_count = get_tree().get_nodes_in_group("pickups").size()
		if current_count < max_active_pickups:
			spawn_random_pickup()

func spawn_random_pickup() -> Pickup:
	if not pickup_scene:
		return null

	var p = pickup_scene.instantiate() as Pickup
	if not p:
		return null

	# Random location in arena
	var rand_x = randf_range(-arena_boundary, arena_boundary)
	var rand_z = randf_range(-arena_boundary, arena_boundary)
	p.position = Vector3(rand_x, 0.8, rand_z)

	# Weighted type selection: Energy (40%), Nitro (25%), Shield (15%), EMP (10%), Smoke (10%)
	var r = randf()
	if r < 0.40:
		p.pickup_type = Pickup.PickupType.ENERGY
	elif r < 0.65:
		p.pickup_type = Pickup.PickupType.NITRO
	elif r < 0.80:
		p.pickup_type = Pickup.PickupType.SHIELD
	elif r < 0.90:
		p.pickup_type = Pickup.PickupType.EMP
	else:
		p.pickup_type = Pickup.PickupType.SMOKE

	add_child(p)
	return p
