class_name Minimap
extends Control

signal size_toggled(is_maximized: bool)

@export var arena_world_radius: float = 90.0
@export var is_maximized: bool = false

var player: Node3D
var destination: Node3D

var _pulse_time: float = 0.0
var _normal_size: Vector2 = Vector2(184, 184)
var _maximized_size: Vector2 = Vector2(480, 480)

@onready var title_label: Label = $HeaderBox/TitleLabel
@onready var hint_label: Label = $HeaderBox/HintLabel
@onready var health_bar: ProgressBar = $BottomBars/MeterHBox/HealthBar
@onready var armor_bar: ProgressBar = $BottomBars/MeterHBox/ArmorBar
@onready var location_label: Label = $BottomBars/LocationLabel

func _ready() -> void:
	custom_minimum_size = _normal_size
	size = _normal_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_maximize()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_maximize()

func toggle_maximize() -> void:
	is_maximized = !is_maximized
	if SoundManager.instance:
		SoundManager.instance.play_blip()

	var target_sz = _maximized_size if is_maximized else _normal_size
	custom_minimum_size = target_sz
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "size", target_sz, 0.22)

	if hint_label:
		hint_label.text = "[M] 🗕" if is_maximized else "[M] ⛶"

	size_toggled.emit(is_maximized)

func _process(delta: float) -> void:
	_pulse_time += delta
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(destination):
		destination = get_tree().get_first_node_in_group("safe_zone") as Node3D

	# Update GTA V Mini Telemetry Bars
	if is_instance_valid(player) and player is PlayerController:
		var p = player as PlayerController
		if health_bar:
			health_bar.value = (float(p.lives) / 3.0) * 100.0
		if armor_bar:
			armor_bar.value = 100.0 if p.has_shield else 0.0

	# Update GPS distance
	if title_label and is_instance_valid(destination) and is_instance_valid(player):
		var dist = int(player.global_position.distance_to(destination.global_position))
		title_label.text = "GPS ➔ %dm" % dist

	var gc = get_tree().current_scene as GameController
	if location_label and gc:
		location_label.text = "SECTOR %02d // DISTRICT %d" % [gc._current_level, (gc._current_level - 1) / 10 + 1]

	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	# Radar active radius fits cleanly between header and bottom meters
	var map_radius = min(size.x, size.y) * 0.38

	# 1. GTA V DARK GREEN TERRAIN BACKDROP
	draw_circle(center, map_radius, Color(0.10, 0.17, 0.12, 0.95))
	draw_arc(center, map_radius, 0.0, TAU, 48, Color(0.35, 0.45, 0.55, 0.8), 2.0)

	var arena_scale = map_radius / max(10.0, arena_world_radius)
	var arena_half_ext = (arena_world_radius * 0.85) * arena_scale

	# 2. ARENA PERIMETER BOUNDARY BOX
	var wall_rect = Rect2(center - Vector2(arena_half_ext, arena_half_ext), Vector2(arena_half_ext * 2.0, arena_half_ext * 2.0))
	draw_rect(wall_rect, Color(0.2, 0.3, 0.4, 0.6), false, 1.5)

	# 3. GTA V CRISP BRIGHT WHITE ROAD NETWORK
	# Roads in GTA V are solid bright white/light cream with dark borders!
	var block_scaled = 56.0 * arena_scale
	var road_w_scaled = max(4.5, 20.0 * arena_scale)
	var road_border_w = road_w_scaled + 2.0

	for i in range(-2, 3):
		var offset = i * block_scaled
		var y_pos = center.y + offset
		if abs(offset) < arena_half_ext:
			# Road dark outline
			draw_line(Vector2(center.x - arena_half_ext, y_pos), Vector2(center.x + arena_half_ext, y_pos), Color(0.08, 0.12, 0.15, 0.9), road_border_w)
			# Solid bright white road ribbon
			draw_line(Vector2(center.x - arena_half_ext, y_pos), Vector2(center.x + arena_half_ext, y_pos), Color(0.96, 0.98, 1.0, 0.95), road_w_scaled)

		var x_pos = center.x + offset
		if abs(offset) < arena_half_ext:
			# Road dark outline
			draw_line(Vector2(x_pos, center.y - arena_half_ext), Vector2(x_pos, center.y + arena_half_ext), Color(0.08, 0.12, 0.15, 0.9), road_border_w)
			# Solid bright white road ribbon
			draw_line(Vector2(x_pos, center.y - arena_half_ext), Vector2(x_pos, center.y + arena_half_ext), Color(0.96, 0.98, 1.0, 0.95), road_w_scaled)

	# 4. GTA V GPS ROUTE LINE TO DESTINATION
	if is_instance_valid(player) and is_instance_valid(destination):
		var p_map = _world_to_map_clamped(player.global_position, center, map_radius)
		var dest_map = _world_to_map_clamped(destination.global_position, center, map_radius)
		# Vibrant yellow GPS guide line
		draw_line(p_map, dest_map, Color(1.0, 0.82, 0.0, 0.7), 2.5)

	# 5. DRAW PICKUPS (Vibrant Colored Dots)
	var pickups = get_tree().get_nodes_in_group("pickups")
	for pk in pickups:
		if is_instance_valid(pk) and pk is Node3D:
			var p_pos = _world_to_map_clamped((pk as Node3D).global_position, center, map_radius)
			draw_circle(p_pos, 3.5, Color(0.65, 0.25, 0.95, 0.95))
			draw_arc(p_pos, 4.0, 0.0, TAU, 10, Color.BLACK, 1.0)

	# 6. DRAW POLICE VEHICLES & SEARCH CONES (GTA V Wanted Radar Style)
	var cops = get_tree().get_nodes_in_group("police")
	for cop in cops:
		if is_instance_valid(cop) and cop is Node3D:
			var cop_pos = _world_to_map_clamped((cop as Node3D).global_position, center, map_radius)
			var flash = fmod(_pulse_time * 7.0, 1.0) > 0.5
			var cop_col = Color(0.95, 0.15, 0.15, 1.0) if flash else Color(0.2, 0.5, 1.0, 1.0)

			# GTA V Red Search Radius Halo
			draw_circle(cop_pos, 10.0, Color(0.95, 0.2, 0.2, 0.18))
			draw_arc(cop_pos, 10.0, 0.0, TAU, 16, Color(0.95, 0.2, 0.2, 0.45), 1.0)

			# Blip Icon (Circular with dark border)
			draw_circle(cop_pos, 4.5, Color(0.05, 0.05, 0.05, 1.0))
			draw_circle(cop_pos, 3.5, cop_col)

	# 7. DRAW DESTINATION WAYPOINT (GTA V Solid Yellow Blip with Edge-Pinning)
	if is_instance_valid(destination):
		var raw_offset = Vector2(destination.global_position.x, destination.global_position.z) * arena_scale
		var is_offscreen = raw_offset.length() > map_radius - 6.0
		var dest_pos = center + (raw_offset.normalized() * (map_radius - 6.0) if is_offscreen else raw_offset)

		# Pulsing GPS Beacon Ring
		var pulse_rad = 6.0 + sin(_pulse_time * 5.0) * 2.0
		draw_arc(dest_pos, pulse_rad + 4.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.1, 0.6), 1.5)

		# Iconic Yellow Waypoint Marker
		draw_circle(dest_pos, 6.0, Color(0.08, 0.08, 0.08, 1.0))
		draw_circle(dest_pos, 4.5, Color(1.0, 0.82, 0.05, 1.0))

		# Edge-Pinning Directional Arrow
		if is_offscreen:
			var arrow_dir = raw_offset.normalized()
			var a_tip = dest_pos + arrow_dir * 5.0
			var a_l = dest_pos - arrow_dir * 3.0 + Vector2(-arrow_dir.y, arrow_dir.x) * 4.0
			var a_r = dest_pos - arrow_dir * 3.0 - Vector2(-arrow_dir.y, arrow_dir.x) * 4.0
			draw_colored_polygon(PackedVector2Array([a_tip, a_l, a_r]), Color(1.0, 0.82, 0.05, 1.0))

	# 8. DRAW PLAYER VEHICLE & GTA V TRANSLUCENT VISION CONE
	if is_instance_valid(player):
		var p_map_pos = _world_to_map_clamped(player.global_position, center, map_radius)
		var forward_angle = -player.rotation.y + PI * 0.5
		var heading_vec = Vector2(cos(forward_angle), -sin(forward_angle))

		# GTA V Translucent Forward Vision Cone (Camera Field of View)
		var cone_dist = 30.0 if is_maximized else 22.0
		var half_fov = deg_to_rad(26.0)
		var left_cone_ray = Vector2(cos(forward_angle - half_fov), -sin(forward_angle - half_fov)) * cone_dist
		var right_cone_ray = Vector2(cos(forward_angle + half_fov), -sin(forward_angle + half_fov)) * cone_dist
		var cone_pts = PackedVector2Array([p_map_pos, p_map_pos + left_cone_ray, p_map_pos + right_cone_ray])
		draw_colored_polygon(cone_pts, Color(0.1, 0.85, 1.0, 0.18))
		draw_line(p_map_pos, p_map_pos + left_cone_ray, Color(0.2, 0.9, 1.0, 0.35), 1.0)
		draw_line(p_map_pos, p_map_pos + right_cone_ray, Color(0.2, 0.9, 1.0, 0.35), 1.0)

		# Player Chevron
		var right_vec = Vector2(-heading_vec.y, heading_vec.x)
		var tip = p_map_pos + heading_vec * 8.5
		var left_corner = p_map_pos - heading_vec * 5.5 - right_vec * 5.0
		var right_corner = p_map_pos - heading_vec * 5.5 + right_vec * 5.0
		var inner_notch = p_map_pos - heading_vec * 2.5

		var poly_pts = PackedVector2Array([tip, left_corner, inner_notch, right_corner])
		draw_colored_polygon(poly_pts, Color(1.0, 1.0, 1.0, 1.0))
		draw_polyline(poly_pts, Color(0.1, 0.15, 0.2, 1.0), 1.5)
		draw_circle(p_map_pos, 2.0, Color(0.0, 0.85, 1.0, 1.0))

	# 9. NORTH COMPASS POINTER
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(center.x - 4, center.y - map_radius + 12), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.9, 0.95, 1.0, 0.9))

func _world_to_map_clamped(world_pos: Vector3, center: Vector2, max_radius: float) -> Vector2:
	var scale_factor = max_radius / max(10.0, arena_world_radius)
	var offset = Vector2(world_pos.x, world_pos.z) * scale_factor
	if offset.length() > max_radius - 2.0:
		offset = offset.normalized() * (max_radius - 2.0)
	return center + offset
