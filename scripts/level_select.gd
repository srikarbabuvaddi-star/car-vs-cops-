class_name LevelSelect
extends Control

signal level_selected(level_number: int)
signal back_pressed()

@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var worlds_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/WorldsContainer
@onready var progress_label: Label = $MarginContainer/VBoxContainer/TopBar/ProgressLabel
@onready var stars_label: Label = $MarginContainer/VBoxContainer/TopBar/StarsLabel
@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton

func _ready() -> void:
	SaveManager.ensure_loaded()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	build_level_grid()

func _on_back_pressed() -> void:
	back_pressed.emit()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func build_level_grid() -> void:
	for child in worlds_container.get_children():
		child.queue_free()

	var highest_unlocked = int(SaveManager.data.get("highest_unlocked_level", 1))
	var completed_levels: Array = SaveManager.data.get("completed_levels", [])
	var total_stars = 0

	# Calculate total stars
	var star_dict: Dictionary = SaveManager.data.get("stars", {})
	for k in star_dict.keys():
		total_stars += int(star_dict[k])

	if progress_label:
		progress_label.text = "%d / 100 UNLOCKED" % highest_unlocked
	if stars_label:
		stars_label.text = "★ %d / 300" % total_stars

	# 10 Worlds x 10 Levels
	for w in range(1, 11):
		var world_panel = _create_world_panel(w, highest_unlocked, completed_levels)
		worlds_container.add_child(world_panel)

func _create_world_panel(world_idx: int, highest_unlocked: int, completed_levels: Array) -> VBoxContainer:
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 10)

	# World Header
	var title_lbl = Label.new()
	var start_lvl = (world_idx - 1) * 10 + 1
	var end_lvl = world_idx * 10
	var w_title = LevelConfig.get_world_title(world_idx)
	title_lbl.text = "WORLD %02d — %s (LEVELS %02d - %02d)" % [world_idx, w_title, start_lvl, end_lvl]
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 0.75, 1.0, 1.0))
	v_box.add_child(title_lbl)

	# Connected Levels Row / Grid
	var h_flow = HFlowContainer.new()
	h_flow.add_theme_constant_override("h_separation", 14)
	h_flow.add_theme_constant_override("v_separation", 14)

	for lvl in range(start_lvl, end_lvl + 1):
		var is_unlocked = lvl <= highest_unlocked
		var is_completed = completed_levels.has(lvl)
		var is_current = (lvl == highest_unlocked)
		var stars = SaveManager.get_level_stars(lvl)
		var best_score = SaveManager.get_level_best_score(lvl)

		var btn = _create_level_button(lvl, is_unlocked, is_completed, is_current, stars, best_score)
		h_flow.add_child(btn)

		# Arrow separator between nodes in row (if not last in world)
		if lvl < end_lvl:
			var arrow = Label.new()
			arrow.text = "→"
			arrow.add_theme_color_override("font_color", Color(0.25, 0.35, 0.45, 0.6))
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h_flow.add_child(arrow)

	v_box.add_child(h_flow)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	v_box.add_child(spacer)

	return v_box

func _create_level_button(lvl: int, unlocked: bool, completed: bool, is_current: bool, stars: int, best_score: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(95, 80)
	btn.focus_mode = FOCUS_NONE

	var star_str = ""
	if completed:
		for s in range(stars):
			star_str += "★"
		for s in range(3 - stars):
			star_str += "☆"

	if completed:
		btn.text = "%02d\n✓ %s\n%d" % [lvl, star_str, best_score]
		btn.modulate = Color(0.2, 0.95, 0.45, 1.0)
	elif is_current:
		btn.text = "%02d\nPLAY ▶" % lvl
		btn.modulate = Color(1.0, 0.75, 0.1, 1.0)
	elif unlocked:
		btn.text = "%02d\nUNLOCKED" % lvl
		btn.modulate = Color(0.7, 0.85, 1.0, 1.0)
	else:
		btn.text = "%02d\n🔒" % lvl
		btn.disabled = true
		btn.modulate = Color(0.35, 0.38, 0.45, 0.6)

	if unlocked:
		btn.pressed.connect(func(): _on_level_clicked(lvl))

	return btn

func _on_level_clicked(lvl: int) -> void:
	level_selected.emit(lvl)
	# Set current level in global or GameManager and load Game.tscn
	SaveManager.data["target_level"] = lvl
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
