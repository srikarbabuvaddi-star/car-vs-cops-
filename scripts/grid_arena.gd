class_name GridArena
extends Node3D

@export var arena_size: float = 180.0
@export var wall_thickness: float = 2.4
@export var wall_height: float = 4.0

@onready var floor_mesh: MeshInstance3D = $FloorMesh
@onready var walls_node: Node3D = $Walls

var _barrier_material: StandardMaterial3D
var _post_material: StandardMaterial3D
var _foliage_material: StandardMaterial3D
var _wood_material: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	setup_arena(arena_size)

func _init_materials() -> void:
	_barrier_material = StandardMaterial3D.new()
	_barrier_material.albedo_color = Color(0.06, 0.09, 0.16, 1.0)
	_barrier_material.metallic = 0.8
	_barrier_material.roughness = 0.25
	_barrier_material.emission_enabled = true
	_barrier_material.emission = Color(0.0, 0.8, 1.0, 1.0)
	_barrier_material.emission_energy_multiplier = 2.8

	_post_material = StandardMaterial3D.new()
	_post_material.albedo_color = Color(0.08, 0.12, 0.2, 1.0)
	_post_material.emission_enabled = true
	_post_material.emission = Color(1.0, 0.45, 0.05, 1.0)
	_post_material.emission_energy_multiplier = 4.0

	_foliage_material = StandardMaterial3D.new()
	_foliage_material.albedo_color = Color(0.18, 0.52, 0.20, 1.0) # Lush park tree green
	_foliage_material.roughness = 0.85

	_wood_material = StandardMaterial3D.new()
	_wood_material.albedo_color = Color(0.35, 0.24, 0.16, 1.0) # Tree trunk wood
	_wood_material.roughness = 0.9

func setup_arena(size: float) -> void:
	arena_size = size
	if floor_mesh and floor_mesh.mesh is PlaneMesh:
		(floor_mesh.mesh as PlaneMesh).size = Vector2(arena_size * 1.6, arena_size * 1.6)

	# Rebuild perimeter barrier walls & decor
	for child in walls_node.get_children():
		child.queue_free()

	var half_size = arena_size * 0.5
	# North wall
	_create_wall(Vector3(0, wall_height * 0.5, -half_size), Vector3(arena_size + wall_thickness * 2, wall_height, wall_thickness))
	# South wall
	_create_wall(Vector3(0, wall_height * 0.5, half_size), Vector3(arena_size + wall_thickness * 2, wall_height, wall_thickness))
	# East wall
	_create_wall(Vector3(half_size, wall_height * 0.5, 0), Vector3(wall_thickness, wall_height, arena_size))
	# West wall
	_create_wall(Vector3(-half_size, wall_height * 0.5, 0), Vector3(wall_thickness, wall_height, arena_size))

	# 4 Corner Cyber Pylons
	_create_corner_pylon(Vector3(-half_size, 0, -half_size))
	_create_corner_pylon(Vector3(half_size, 0, -half_size))
	_create_corner_pylon(Vector3(-half_size, 0, half_size))
	_create_corner_pylon(Vector3(half_size, 0, half_size))

	# Decorative Park Trees in Garden Blocks (centered at 56m grid offsets ±28m)
	_spawn_park_vegetation(half_size)

func _create_wall(pos: Vector3, size: Vector3) -> void:
	var static_body = StaticBody3D.new()
	static_body.add_to_group("obstacles")
	static_body.collision_layer = 4
	static_body.collision_mask = 3
	static_body.transform.origin = pos

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	static_body.add_child(col_shape)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = _barrier_material
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)

	walls_node.add_child(static_body)

func _create_corner_pylon(pos: Vector3) -> void:
	var pylon = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.8
	cyl.height = wall_height * 1.6
	cyl.material = _post_material
	pylon.mesh = cyl
	pylon.position = pos + Vector3(0, cyl.height * 0.5, 0)
	walls_node.add_child(pylon)

func _spawn_park_vegetation(max_extent: float) -> void:
	var block_size = 56.0
	var offsets = [-block_size, 0.0, block_size]

	for ox in offsets:
		for oz in offsets:
			# Garden block centers are at ox + 28, oz + 28
			var garden_center_x = ox + 28.0
			var garden_center_z = oz + 28.0
			if abs(garden_center_x) < max_extent - 16.0 and abs(garden_center_z) < max_extent - 16.0:
				_create_tree(Vector3(garden_center_x - 4.0, 0, garden_center_z - 4.0), 1.1)
				_create_tree(Vector3(garden_center_x + 5.0, 0, garden_center_z + 4.0), 0.9)
				_create_tree(Vector3(garden_center_x + 4.0, 0, garden_center_z - 5.0), 1.25)

func _create_tree(pos: Vector3, scale_mult: float) -> void:
	var tree_node = Node3D.new()
	tree_node.position = pos

	# Trunk
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.25 * scale_mult
	trunk_mesh.bottom_radius = 0.35 * scale_mult
	trunk_mesh.height = 2.0 * scale_mult
	trunk_mesh.material = _wood_material
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.0 * scale_mult
	tree_node.add_child(trunk)

	# Canopy (Dual Sphere / Cone Foliage)
	var canopy = MeshInstance3D.new()
	var canopy_mesh = SphereMesh.new()
	canopy_mesh.radius = 1.6 * scale_mult
	canopy_mesh.height = 2.8 * scale_mult
	canopy_mesh.material = _foliage_material
	canopy.mesh = canopy_mesh
	canopy.position.y = 2.8 * scale_mult
	tree_node.add_child(canopy)

	walls_node.add_child(tree_node)
