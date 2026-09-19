class_name Pickup
extends Area3D

enum PickupType {
	ENERGY,
	NITRO,
	EMP,
	SHIELD,
	SMOKE
}

@export var pickup_type: PickupType = PickupType.ENERGY
@export var rotation_speed: float = 2.4
@export var bob_amplitude: float = 0.35
@export var bob_frequency: float = 3.0

var _base_y: float = 0.8
var _time: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var omni_light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	add_to_group("pickups")
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _setup_visuals() -> void:
	var col = Color(0.66, 0.33, 0.97, 1.0) # Purple #A855F7
	match pickup_type:
		PickupType.ENERGY:
			col = Color(0.7, 0.25, 1.0, 1.0)
		PickupType.NITRO:
			col = Color(0.1, 0.8, 1.0, 1.0) # Cyan/Nitro
		PickupType.EMP:
			col = Color(1.0, 0.85, 0.1, 1.0) # Electric Yellow
		PickupType.SHIELD:
			col = Color(0.2, 0.95, 0.4, 1.0) # Emerald Shield
		PickupType.SMOKE:
			col = Color(0.8, 0.85, 0.95, 1.0) # Ghostly smoke

	if is_instance_valid(omni_light):
		omni_light.light_color = col

	if is_instance_valid(mesh_instance):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 3.2
		mat.metallic = 0.4
		mat.roughness = 0.2
		mesh_instance.material_override = mat

func _process(delta: float) -> void:
	_time += delta
	# Slow rotation
	rotate_y(rotation_speed * delta)
	# Vertical floating bob
	position.y = _base_y + sin(_time * bob_frequency) * bob_amplitude

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var p = body as PlayerController
		if p:
			_apply_effect(p)
			queue_free()

func _apply_effect(player: PlayerController) -> void:
	var tree = get_tree()
	if not tree and player:
		tree = player.get_tree()
	if not tree:
		return

	match pickup_type:
		PickupType.ENERGY:
			var score_mgr = tree.get_first_node_in_group("score_manager") as ScoreManager
			if score_mgr:
				score_mgr.add_points(500)
			var lvl_mgr = tree.get_first_node_in_group("level_manager") as LevelManager
			if lvl_mgr:
				lvl_mgr.register_pickup_collected()

		PickupType.NITRO:
			player.add_nitro(100.0)

		PickupType.EMP:
			# Stun all active police
			var cops = tree.get_nodes_in_group("police")
			for cop in cops:
				if cop is PoliceAI:
					(cop as PoliceAI).stun(4.0)

		PickupType.SHIELD:
			player.activate_shield()

		PickupType.SMOKE:
			# Confuse active police
			var cops = tree.get_nodes_in_group("police")
			for cop in cops:
				if cop is PoliceAI:
					(cop as PoliceAI).bounce_impulse = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
