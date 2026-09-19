class_name SafeZone
extends Area3D

signal entered_safe_zone()

@export var radius: float = 8.0
@export var pulse_speed: float = 3.5

var _time: float = 0.0
@onready var ring_mesh: MeshInstance3D = $RingMesh
@onready var torus_mesh: MeshInstance3D = $TorusMesh
@onready var beacon_mesh: MeshInstance3D = $BeaconMesh
@onready var omni_light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	add_to_group("safe_zone")
	body_entered.connect(_on_body_entered)
	_setup_materials()

func _setup_materials() -> void:
	var mat_ring = StandardMaterial3D.new()
	mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring.albedo_color = Color(0.1, 0.95, 0.55, 0.5)
	mat_ring.emission_enabled = true
	mat_ring.emission = Color(0.15, 1.0, 0.6, 1.0)
	mat_ring.emission_energy_multiplier = 4.5
	if ring_mesh:
		ring_mesh.material_override = mat_ring

	var mat_torus = StandardMaterial3D.new()
	mat_torus.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_torus.albedo_color = Color(0.2, 1.0, 0.65, 0.8)
	mat_torus.emission_enabled = true
	mat_torus.emission = Color(0.2, 1.0, 0.7, 1.0)
	mat_torus.emission_energy_multiplier = 6.0
	if torus_mesh:
		torus_mesh.material_override = mat_torus

	var mat_beacon = StandardMaterial3D.new()
	mat_beacon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_beacon.albedo_color = Color(0.15, 1.0, 0.6, 0.4)
	mat_beacon.emission_enabled = true
	mat_beacon.emission = Color(0.15, 1.0, 0.6, 1.0)
	mat_beacon.emission_energy_multiplier = 5.0
	if beacon_mesh:
		beacon_mesh.material_override = mat_beacon

func _process(delta: float) -> void:
	_time += delta
	var pulse = 1.0 + sin(_time * pulse_speed) * 0.12
	if ring_mesh:
		ring_mesh.scale = Vector3(pulse, 1.0, pulse)
	if torus_mesh:
		torus_mesh.rotation.y += delta * 2.0
	if beacon_mesh:
		beacon_mesh.rotation.y += delta * 1.2

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		entered_safe_zone.emit()
		var lvl_mgr = get_tree().get_first_node_in_group("level_manager") as LevelManager
		if lvl_mgr and lvl_mgr.is_game_active:
			lvl_mgr.register_safe_zone_entered()
			lvl_mgr.trigger_completion()
		if SoundManager.instance:
			SoundManager.instance.play_win()
