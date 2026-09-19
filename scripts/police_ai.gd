class_name PoliceAI
extends CharacterBody3D

enum PoliceType { CHASER, INTERCEPTOR, BLOCKER, SWARM }

@export var police_type: PoliceType = PoliceType.CHASER
@export var base_speed: float = 21.0
@export var acceleration: float = 26.0
@export var steer_rate: float = 3.2
@export var speed_multiplier: float = 1.0

# References
var player_target: Node3D = null
var current_speed: float = 0.0
var stun_timer: float = 0.0
var is_stunned: bool = false
var swarm_angle_offset: float = 0.0 # Used by Swarm type
var bounce_impulse: Vector3 = Vector3.ZERO

# Siren / Lightbar
var _flash_timer: float = 0.0
var _flash_state: bool = false

# Child Nodes
@onready var light_red_mesh: MeshInstance3D = $ModelRoot/Lightbar/RedLight
@onready var light_blue_mesh: MeshInstance3D = $ModelRoot/Lightbar/BlueLight
@onready var omni_red: OmniLight3D = $ModelRoot/Lightbar/OmniRed
@onready var omni_blue: OmniLight3D = $ModelRoot/Lightbar/OmniBlue
@onready var model_root: Node3D = $ModelRoot

func _ready() -> void:
	add_to_group("police")
	if not player_target:
		player_target = get_tree().get_first_node_in_group("player") as Node3D

func set_police_type(type: PoliceType) -> void:
	police_type = type

func stun(duration: float = 3.0) -> void:
	is_stunned = true
	stun_timer = duration
	current_speed *= 0.2

func _physics_process(delta: float) -> void:
	_handle_lights(delta)

	if is_stunned:
		stun_timer -= delta
		# Spin out slightly while stunned
		rotate_y(delta * 4.0)
		current_speed = move_toward(current_speed, 0.0, 15.0 * delta)
		var forward = -global_transform.basis.z.normalized()
		velocity = forward * current_speed + bounce_impulse
		bounce_impulse = bounce_impulse.move_toward(Vector3.ZERO, 20.0 * delta)
		velocity.y = 0.0
		move_and_slide()
		if stun_timer <= 0.0:
			is_stunned = false
		return

	if not is_instance_valid(player_target):
		player_target = get_tree().get_first_node_in_group("player") as Node3D
		if not player_target:
			return

	var target_pos = _calculate_target_position()
	_navigate_toward(target_pos, delta)

func _handle_lights(delta: float) -> void:
	_flash_timer += delta
	if _flash_timer >= 0.12:
		_flash_timer = 0.0
		_flash_state = !_flash_state

		if is_instance_valid(light_red_mesh) and is_instance_valid(light_blue_mesh):
			var red_mat = light_red_mesh.get_active_material(0) as StandardMaterial3D
			var blue_mat = light_blue_mesh.get_active_material(0) as StandardMaterial3D
			if red_mat:
				red_mat.emission_enabled = _flash_state
			if blue_mat:
				blue_mat.emission_enabled = not _flash_state

		if is_instance_valid(omni_red):
			omni_red.visible = _flash_state
		if is_instance_valid(omni_blue):
			omni_blue.visible = not _flash_state

func _calculate_target_position() -> Vector3:
	var p_pos = player_target.global_position
	var p_vel = Vector3.ZERO
	if player_target is CharacterBody3D:
		p_vel = player_target.velocity

	var to_player = p_pos - global_position
	var dist = to_player.length()

	match police_type:
		PoliceType.CHASER:
			# Direct pursuit
			return p_pos

		PoliceType.INTERCEPTOR:
			# Predict player heading ahead
			var look_time = clamp(dist / (base_speed * speed_multiplier + 0.1), 0.3, 1.8)
			return p_pos + p_vel * look_time

		PoliceType.BLOCKER:
			# Get ahead and establish a roadblock line
			var p_forward = -player_target.global_transform.basis.z.normalized()
			var block_point = p_pos + p_forward * 18.0
			return block_point

		PoliceType.SWARM:
			# Flank player with angle offset
			var offset_dist = 6.0
			var flank_vec = Vector3(cos(swarm_angle_offset), 0, sin(swarm_angle_offset)) * offset_dist
			var base_swarm_target = p_pos + flank_vec
			# Add separation from other police cars
			var sep = _compute_police_separation()
			return base_swarm_target + sep * 4.0

	return p_pos

func _compute_police_separation() -> Vector3:
	var sep = Vector3.ZERO
	var cops = get_tree().get_nodes_in_group("police")
	for cop in cops:
		if cop != self and is_instance_valid(cop) and cop is Node3D:
			var diff = global_position - cop.global_position
			var d = diff.length()
			if d > 0.01 and d < 5.0:
				sep += diff.normalized() * (1.0 - (d / 5.0))
	return sep

func _navigate_toward(target_pos: Vector3, delta: float) -> void:
	var to_target = target_pos - global_position
	to_target.y = 0.0

	if to_target.length_squared() < 0.2:
		return

	var desired_dir = to_target.normalized()
	var current_dir = -global_transform.basis.z.normalized()

	# Calculate signed angle between current forward and desired direction
	var angle_diff = current_dir.signed_angle_to(desired_dir, Vector3.UP)

	# Steer smoothly
	var max_steer = steer_rate * delta
	var steer_step = clamp(angle_diff, -max_steer, max_steer)
	rotate_y(steer_step)

	# Body roll tilt while turning
	if model_root:
		var target_roll = clamp(angle_diff * 0.4, -0.1, 0.1)
		model_root.rotation.z = lerpf(model_root.rotation.z, target_roll, 8.0 * delta)

	# Forward movement
	var target_speed = base_speed * speed_multiplier
	# Slow down slightly during very sharp turns to maintain grip
	if abs(angle_diff) > 1.2:
		target_speed *= 0.65

	current_speed = move_toward(current_speed, target_speed, acceleration * delta)

	var forward = -global_transform.basis.z.normalized()
	velocity = forward * current_speed + bounce_impulse
	bounce_impulse = bounce_impulse.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.y = 0.0

	move_and_slide()
	global_position.y = 0.1
	velocity.y = 0.0

	_handle_collisions()

func _handle_collisions() -> void:
	var col_count = get_slide_collision_count()
	for i in range(col_count):
		var col = get_slide_collision(i)
		var collider = col.get_collider()

		if collider and collider.is_in_group("player"):
			var p = collider as PlayerController
			if p and not p.is_invulnerable:
				var push_dir = (p.global_position - global_position).normalized()
				if p.has_shield:
					p.apply_damage(1, push_dir) # Shield absorbs
				else:
					p.apply_damage(p.lives, push_dir) # Cops caught the car -> GAME OVER!
				bounce_impulse = -push_dir * 12.0
				current_speed *= 0.3
				var cam = get_viewport().get_camera_3d() as CameraFollow
				if cam:
					cam.add_trauma(0.6)

		elif collider and collider.is_in_group("police"):
			var other_cop = collider as PoliceAI
			_trigger_cop_blast(other_cop, col.get_position())
			return

		elif collider and collider.is_in_group("obstacles"):
			var normal = col.get_normal()
			bounce_impulse = normal * 14.0
			current_speed *= 0.4

func _trigger_cop_blast(other_cop: PoliceAI, hit_pos: Vector3) -> void:
	if is_queued_for_deletion():
		return

	var explosion_scene = load("res://scenes/Explosion.tscn")
	if explosion_scene:
		var exp_inst = explosion_scene.instantiate() as Node3D
		get_parent().add_child(exp_inst)
		exp_inst.global_position = hit_pos
		if SoundManager.instance:
			SoundManager.instance.play_explosion()

	var score_mgr = get_tree().get_first_node_in_group("score_manager") as ScoreManager
	if score_mgr:
		score_mgr.add_points(500)

	var gc = get_tree().current_scene as GameController
	if gc and gc.hud:
		gc.hud.show_toast("COP WRECKED! +500", Color(1.0, 0.4, 0.1))

	if is_instance_valid(other_cop) and not other_cop.is_queued_for_deletion():
		other_cop.queue_free()
	queue_free()
