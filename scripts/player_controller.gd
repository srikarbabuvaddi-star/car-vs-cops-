class_name PlayerController
extends CharacterBody3D

signal nitro_changed(current: float, max_val: float)
signal speed_changed(current_speed: float, max_speed: float)
signal life_lost(remaining_lives: int)
signal close_call_triggered(police_ref: Node3D)

# Driving Physics Parameters
@export var max_speed: float = 26.0
@export var acceleration: float = 34.0
@export var reverse_max_speed: float = 12.0
@export var brake_force: float = 42.0
@export var natural_drag: float = 4.0
@export var steer_speed: float = 3.6
@export var drift_slip_factor: float = 0.88 # Lower means more slide/drift
@export var grip_recovery: float = 8.0

# Nitro Parameters
@export var nitro_top_speed: float = 38.0
@export var nitro_acceleration: float = 58.0
@export var max_nitro: float = 100.0
@export var nitro_drain_rate: float = 30.0
@export var nitro_regen_rate: float = 6.0

# Visual Tilt & Aesthetics
@export var max_roll_tilt: float = 0.12 # Radians
@export var max_pitch_tilt: float = 0.08

# State Variables
var current_speed: float = 0.0
var lateral_velocity: Vector3 = Vector3.ZERO
var forward_velocity: Vector3 = Vector3.ZERO
var is_drifting: bool = false
var is_nitro_active: bool = false
var nitro_amount: float = 100.0
var lives: int = 3
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var bounce_impulse: Vector3 = Vector3.ZERO
var has_shield: bool = false
var _close_call_cooldown: float = 0.0

# Child References
@onready var model_root: Node3D = $ModelRoot
@onready var left_smoke: CPUParticles3D = $LeftSmoke
@onready var right_smoke: CPUParticles3D = $RightSmoke
@onready var nitro_flames: CPUParticles3D = $NitroFlames
@onready var tire_marks_left: TireMarks = $TireMarksLeft
@onready var tire_marks_right: TireMarks = $TireMarksRight
@onready var shield_mesh: MeshInstance3D = $ModelRoot/ShieldMesh
@onready var close_call_area: Area3D = $CloseCallArea

func _ready() -> void:
	nitro_amount = max_nitro
	nitro_changed.emit(nitro_amount, max_nitro)
	if close_call_area:
		close_call_area.body_entered.connect(_on_close_call_body_entered)
	_setup_shield_material()

func _setup_shield_material() -> void:
	if shield_mesh:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.15, 0.95, 0.6, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.7, 1.0)
		mat.emission_energy_multiplier = 3.0
		shield_mesh.material_override = mat

func activate_shield() -> void:
	has_shield = true
	if shield_mesh:
		shield_mesh.visible = true

func _handle_invulnerability(delta: float) -> void:
	if is_invulnerable:
		invulnerable_timer -= delta
		# Visual blink
		if model_root:
			model_root.visible = fmod(invulnerable_timer, 0.16) > 0.08
		if invulnerable_timer <= 0.0:
			is_invulnerable = false
			if model_root:
				model_root.visible = true
	else:
		if model_root and not model_root.visible:
			model_root.visible = true

# Input simulation / overrides (useful for testing & cutscenes)
var manual_forward: float = 0.0
var manual_steer: float = 0.0
var manual_nitro: bool = false

func _handle_input_and_movement(delta: float) -> void:
	var forward_input = Input.get_axis("brake", "accelerate")
	if manual_forward != 0.0:
		forward_input = manual_forward

	var steer_input = Input.get_axis("steer_right", "steer_left") # Left is positive yaw
	if manual_steer != 0.0:
		steer_input = manual_steer

	# Nitro Check
	var wants_nitro = (Input.is_action_pressed("nitro") or manual_nitro) and forward_input > 0.1 and nitro_amount > 2.0
	is_nitro_active = wants_nitro

	if is_nitro_active:
		nitro_amount = max(0.0, nitro_amount - nitro_drain_rate * delta)
	else:
		nitro_amount = min(max_nitro, nitro_amount + nitro_regen_rate * delta)
	nitro_changed.emit(nitro_amount, max_nitro)

	var target_max = nitro_top_speed if is_nitro_active else max_speed
	var current_accel = nitro_acceleration if is_nitro_active else acceleration

	# Steering (only when moving)
	var speed_ratio = clamp(abs(current_speed) / 6.0, 0.0, 1.0)
	var steer_direction = 1.0 if current_speed >= 0.0 else -1.0
	var steer_amount = steer_input * steer_speed * speed_ratio * steer_direction * delta

	# Drifting occurs on sharp turns at high speed or when braking while turning
	is_drifting = abs(steer_input) > 0.6 and abs(current_speed) > 10.0

	# Apply rotation around Y
	rotate_y(steer_amount)

	# Forward / Reverse acceleration
	if forward_input > 0.0:
		current_speed = move_toward(current_speed, target_max, current_accel * delta)
	elif forward_input < 0.0:
		if current_speed > 0.5:
			# Braking
			current_speed = move_toward(current_speed, 0.0, brake_force * delta)
		else:
			# Reverse
			current_speed = move_toward(current_speed, -reverse_max_speed, acceleration * 0.7 * delta)
	else:
		# Natural coast drag
		current_speed = move_toward(current_speed, 0.0, natural_drag * delta)

	# Calculate 3D velocity with drift slip
	var car_forward = -global_transform.basis.z.normalized()
	var car_right = global_transform.basis.x.normalized()

	forward_velocity = car_forward * current_speed

	# Lateral drift momentum
	if is_drifting:
		# Maintain some outward slip
		var slip_force = car_right * (steer_input * current_speed * 0.28)
		lateral_velocity = lateral_velocity.lerp(slip_force, 6.0 * delta)
	else:
		lateral_velocity = lateral_velocity.move_toward(Vector3.ZERO, grip_recovery * 10.0 * delta)

	# Combine velocities and apply bounce impulse if any
	velocity = forward_velocity + lateral_velocity + bounce_impulse
	bounce_impulse = bounce_impulse.move_toward(Vector3.ZERO, 35.0 * delta)

	# Keep on arena ground plane
	velocity.y = 0.0

	move_and_slide()
	global_position.y = 0.1
	velocity.y = 0.0

	# Handle collisions
	var col_count = get_slide_collision_count()
	for i in range(col_count):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("obstacles"):
			var normal = col.get_normal()
			bounce_impulse = normal * (abs(current_speed) * 0.4 + 4.0)
			if abs(current_speed) > 14.0:
				apply_damage(lives, normal) # Fatal crash at high speed -> GAME OVER
			else:
				current_speed *= 0.5

	speed_changed.emit(abs(current_speed), target_max)

func _handle_visual_tilt(delta: float) -> void:
	if not model_root:
		return

	var steer_input = Input.get_axis("steer_right", "steer_left")
	var forward_input = Input.get_axis("brake", "accelerate")

	# Roll tilt (car rolls slightly into/away from turn)
	var target_roll = -steer_input * max_roll_tilt * clamp(abs(current_speed) / 12.0, 0.0, 1.0)
	# Pitch tilt (squat on accel, dive on brake)
	var target_pitch = forward_input * max_pitch_tilt * 0.7

	model_root.rotation.z = lerpf(model_root.rotation.z, target_roll, 10.0 * delta)
	model_root.rotation.x = lerpf(model_root.rotation.x, target_pitch, 8.0 * delta)

func _handle_effects() -> void:
	var car_right = global_transform.basis.x.normalized()

	# Tire Smoke and Skid Marks during drift or hard braking
	var should_skid = is_drifting or (Input.is_action_pressed("brake") and current_speed > 6.0)

	if left_smoke:
		left_smoke.emitting = should_skid
	if right_smoke:
		right_smoke.emitting = should_skid

	if tire_marks_left and tire_marks_right:
		if should_skid:
			var rear_left = global_position - car_right * 0.75 + global_transform.basis.z * 1.2
			var rear_right = global_position + car_right * 0.75 + global_transform.basis.z * 1.2
			tire_marks_left.add_mark_point(rear_left, car_right)
			tire_marks_right.add_mark_point(rear_right, car_right)
		else:
			tire_marks_left.stop_strip()
			tire_marks_right.stop_strip()

	if nitro_flames:
		nitro_flames.emitting = is_nitro_active

func _physics_process(delta: float) -> void:
	if _close_call_cooldown > 0.0:
		_close_call_cooldown -= delta
	_handle_invulnerability(delta)
	_handle_input_and_movement(delta)
	_handle_visual_tilt(delta)
	_handle_effects()

func _on_close_call_body_entered(body: Node3D) -> void:
	if body.is_in_group("police") and not is_invulnerable and _close_call_cooldown <= 0.0:
		trigger_close_call(body)

func trigger_close_call(police_ref: Node3D) -> void:
	_close_call_cooldown = 1.0 # Prevent duplicate triggers for the same encounter
	close_call_triggered.emit(police_ref)

	# Time dilation: slow time to 0.25 for 0.18s
	Engine.time_scale = 0.25
	var tree = get_tree()
	var tween = tree.create_tween()
	tween.tween_interval(0.04) # Brief slow-mo duration in slowed time
	tween.tween_property(Engine, "time_scale", 1.0, 0.14)

	# Camera Shake
	var cam = get_viewport().get_camera_3d() as CameraFollow
	if cam:
		cam.add_trauma(0.4)

	# Register with ScoreManager
	var score_mgr = tree.get_first_node_in_group("score_manager") as ScoreManager
	if score_mgr:
		score_mgr.register_close_call()

	# Register with LevelManager
	var lvl_mgr = tree.get_first_node_in_group("level_manager") as LevelManager
	if lvl_mgr:
		lvl_mgr.register_escape()

func apply_damage(amount: int = 1, impulse_dir: Vector3 = Vector3.ZERO) -> void:
	if is_invulnerable:
		return

	# Shield Absorption Check
	if has_shield:
		has_shield = false
		if shield_mesh:
			shield_mesh.visible = false
		is_invulnerable = true
		invulnerable_timer = 1.0
		bounce_impulse = impulse_dir * 14.0
		current_speed *= 0.6
		var cam = get_viewport().get_camera_3d() as CameraFollow
		if cam:
			cam.add_trauma(0.4)
		return

	lives = max(0, lives - amount)
	is_invulnerable = true
	invulnerable_timer = 1.6
	bounce_impulse = impulse_dir * 18.0
	current_speed *= 0.3
	life_lost.emit(lives)

	# Breaking combo on hit
	var score_mgr = get_tree().get_first_node_in_group("score_manager") as ScoreManager
	if score_mgr:
		score_mgr.reset_combo()

func restore_life(amount: int = 1) -> void:
	lives = min(3, lives + amount)
	life_lost.emit(lives)

func add_nitro(amount: float) -> void:
	nitro_amount = min(max_nitro, nitro_amount + amount)
	nitro_changed.emit(nitro_amount, max_nitro)
