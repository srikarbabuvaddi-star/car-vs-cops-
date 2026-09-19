class_name CameraFollow
extends Camera3D

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var base_height: float = 24.0
@export var base_offset_z: float = 12.0
@export var look_ahead_factor: float = 0.35

# Dynamic Zoom
@export var speed_zoom_factor: float = 0.2
@export var max_extra_height: float = 6.0

# Trauma-based Screen Shake
var trauma: float = 0.0
var trauma_power: float = 2.0
var trauma_decay: float = 1.4
var max_shake_offset: Vector3 = Vector3(1.2, 0.4, 1.2)
var max_shake_rotation: Vector3 = Vector3(0.04, 0.04, 0.04)

var _noise_time: float = 0.0
var _base_fov: float = 55.0

func _ready() -> void:
	_base_fov = fov
	# Initial camera angle looking down-forward
	look_at_from_position(
		Vector3(0, base_height, base_offset_z),
		Vector3(0, 0, 0),
		Vector3.UP
	)

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_noise_time += delta * 35.0

	# Shake decay
	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_decay * delta)

	if not is_instance_valid(target):
		return

	var target_pos = target.global_position
	var car_speed = 0.0
	var car_forward = -target.global_transform.basis.z.normalized()

	if target is CharacterBody3D:
		car_speed = target.velocity.length()

	# Look slightly ahead in driving direction
	var look_ahead = car_forward * (car_speed * look_ahead_factor)
	var desired_x = target_pos.x + look_ahead.x
	var desired_z = target_pos.z + look_ahead.z + base_offset_z

	# Dynamic zoom based on speed
	var speed_ratio = clamp(car_speed / 35.0, 0.0, 1.0)
	var target_height = base_height + (speed_ratio * max_extra_height)

	# Smooth follow
	var current_pos = global_position
	current_pos.x = lerpf(current_pos.x, desired_x, follow_speed * delta)
	current_pos.z = lerpf(current_pos.z, desired_z, follow_speed * delta)
	current_pos.y = lerpf(current_pos.y, target_height, follow_speed * 0.5 * delta)

	# Screen shake calculations using pseudo-noise
	var shake_val = pow(trauma, trauma_power)
	var offset_x = sin(_noise_time * 1.1) * max_shake_offset.x * shake_val
	var offset_y = cos(_noise_time * 1.7) * max_shake_offset.y * shake_val
	var offset_z = sin(_noise_time * 1.4) * max_shake_offset.z * shake_val

	global_position = current_pos + Vector3(offset_x, offset_y, offset_z)

	# FOV pulse on trauma
	fov = _base_fov + (shake_val * 3.5)

	# Maintain consistent top-down downward pitch angle
	var look_target = Vector3(current_pos.x, 0.0, current_pos.z - base_offset_z)
	look_at(look_target, Vector3.UP)

	# Shake rotation
	if shake_val > 0.001:
		rotation.x += sin(_noise_time * 2.1) * max_shake_rotation.x * shake_val
		rotation.y += cos(_noise_time * 1.9) * max_shake_rotation.y * shake_val
		rotation.z += sin(_noise_time * 2.5) * max_shake_rotation.z * shake_val
