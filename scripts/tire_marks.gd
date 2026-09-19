class_name TireMarks
extends Node3D

@export var max_marks: int = 150
@export var min_distance: float = 0.4
@export var mark_width: float = 0.28
@export var lifetime: float = 6.0

var _active_strips: Array = []
var _current_strip: MeshInstance3D = null
var _last_left_pos: Vector3 = Vector3.ZERO
var _last_right_pos: Vector3 = Vector3.ZERO
var _is_emitting: bool = false

var _mark_material: StandardMaterial3D

func _ready() -> void:
	_mark_material = StandardMaterial3D.new()
	_mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_material.albedo_color = Color(0.04, 0.05, 0.08, 0.55)
	_mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mark_material.no_depth_test = false

func start_strip() -> void:
	if _is_emitting:
		return
	_is_emitting = true
	_create_new_strip_mesh()

func stop_strip() -> void:
	if not _is_emitting:
		return
	_is_emitting = false
	_current_strip = null

func add_mark_point(wheel_center: Vector3, car_right: Vector3) -> void:
	var left_pt = wheel_center - car_right * (mark_width * 0.5)
	var right_pt = wheel_center + car_right * (mark_width * 0.5)
	left_pt.y = 0.02
	right_pt.y = 0.02

	if not _is_emitting or _current_strip == null:
		start_strip()
		_last_left_pos = left_pt
		_last_right_pos = right_pt
		return

	if _last_left_pos.distance_squared_to(left_pt) < (min_distance * min_distance):
		return

	_append_quad(_last_left_pos, _last_right_pos, left_pt, right_pt)
	_last_left_pos = left_pt
	_last_right_pos = right_pt

func _create_new_strip_mesh() -> void:
	var mesh_inst = MeshInstance3D.new()
	var imm_mesh = ImmediateMesh.new()
	mesh_inst.mesh = imm_mesh
	mesh_inst.material_override = _mark_material
	mesh_inst.top_level = true
	add_child(mesh_inst)
	_current_strip = mesh_inst
	_active_strips.append({"instance": mesh_inst, "mesh": imm_mesh, "age": 0.0, "surfaces": 0})

func _append_quad(p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3) -> void:
	if _current_strip == null:
		return
	var imm: ImmediateMesh = _current_strip.mesh as ImmediateMesh
	if imm == null:
		return

	# Append 2 triangles (quad)
	imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	imm.surface_add_vertex(p1)
	imm.surface_add_vertex(p2)
	imm.surface_add_vertex(p3)

	imm.surface_add_vertex(p2)
	imm.surface_add_vertex(p4)
	imm.surface_add_vertex(p3)
	imm.surface_end()

	if _active_strips.size() > 0:
		_active_strips.back()["surfaces"] += 1

func _process(delta: float) -> void:
	var i = _active_strips.size() - 1
	while i >= 0:
		var item = _active_strips[i]
		item["age"] += delta
		if item["age"] >= lifetime:
			if is_instance_valid(item["instance"]):
				item["instance"].queue_free()
			_active_strips.remove_at(i)
		else:
			# Fade out slightly near end of lifetime
			var alpha = clamp(1.0 - (item["age"] / lifetime), 0.0, 1.0) * 0.55
			if is_instance_valid(item["instance"]):
				var mat = item["instance"].material_override as StandardMaterial3D
				if mat:
					mat.albedo_color.a = alpha
		i -= 1
