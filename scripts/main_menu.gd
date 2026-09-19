class_name MainMenu
extends Control

@onready var btn_play: Button = $Margin/VBox/MenuButtons/PlayButton
@onready var btn_levels: Button = $Margin/VBox/MenuButtons/LevelsButton
@onready var btn_garage: Button = $Margin/VBox/MenuButtons/GarageButton
@onready var btn_settings: Button = $Margin/VBox/MenuButtons/SettingsButton
@onready var btn_help: Button = $Margin/VBox/MenuButtons/HelpButton
@onready var btn_quit: Button = $Margin/VBox/MenuButtons/QuitButton

@onready var stats_label: Label = $Margin/VBox/StatsLabel

# Modals
@onready var help_modal: PanelContainer = $HelpModal
@onready var btn_help_close: Button = $HelpModal/VBox/CloseHelpButton

@onready var garage_modal: PanelContainer = $GarageModal
@onready var btn_garage_close: Button = $GarageModal/VBox/CloseGarageButton

@onready var settings_modal: PanelContainer = $SettingsModal
@onready var check_shake: CheckBox = $SettingsModal/VBox/ShakeCheck
@onready var btn_reset_save: Button = $SettingsModal/VBox/ResetSaveButton
@onready var btn_settings_close: Button = $SettingsModal/VBox/CloseSettingsButton

func _ready() -> void:
	SaveManager.ensure_loaded()
	_ensure_sound_manager()
	_update_stats()
	_connect_signals()
	_hide_all_modals()

func _ensure_sound_manager() -> void:
	if not SoundManager.instance:
		var sm = SoundManager.new()
		get_tree().root.add_child.call_deferred(sm)

func _hide_all_modals() -> void:
	if help_modal:
		help_modal.visible = false
	if garage_modal:
		garage_modal.visible = false
	if settings_modal:
		settings_modal.visible = false

func _update_stats() -> void:
	var highest = int(SaveManager.data.get("highest_unlocked_level", 1))
	var stars_dict: Dictionary = SaveManager.data.get("stars", {})
	var total_stars = 0
	for k in stars_dict.keys():
		total_stars += int(stars_dict[k])

	if stats_label:
		stats_label.text = "MISSION PROGRESS: LEVEL %02d / 100  |  TOTAL STARS: ★ %d / 300" % [highest, total_stars]

func _connect_signals() -> void:
	var all_btns = [btn_play, btn_levels, btn_garage, btn_settings, btn_help, btn_quit, btn_help_close, btn_garage_close, btn_settings_close, btn_reset_save]
	for b in all_btns:
		if is_instance_valid(b):
			b.mouse_entered.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip())

	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
	if btn_levels:
		btn_levels.pressed.connect(_on_levels_pressed)
	if btn_garage:
		btn_garage.pressed.connect(func():
			if SoundManager.instance: SoundManager.instance.play_blip()
			_hide_all_modals()
			garage_modal.visible = true
		)
	if btn_settings:
		btn_settings.pressed.connect(func():
			if SoundManager.instance: SoundManager.instance.play_blip()
			_hide_all_modals()
			_load_settings_values()
			settings_modal.visible = true
		)
	if btn_help:
		btn_help.pressed.connect(func():
			if SoundManager.instance: SoundManager.instance.play_blip()
			_hide_all_modals()
			help_modal.visible = true
		)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)

	if btn_help_close:
		btn_help_close.pressed.connect(func():
			if SoundManager.instance: SoundManager.instance.play_blip()
			help_modal.visible = false
		)
	if btn_garage_close:
		btn_garage_close.pressed.connect(func():
			if SoundManager.instance: SoundManager.instance.play_blip()
			garage_modal.visible = false
		)
	if btn_settings_close:
		btn_settings_close.pressed.connect(func():
			if SoundManager.instance: SoundManager.instance.play_blip()
			settings_modal.visible = false
		)

	if check_shake:
		check_shake.toggled.connect(func(v):
			SaveManager.data.get("settings", {})["screen_shake"] = v
			SaveManager.save_game()
		)
	if btn_reset_save:
		btn_reset_save.pressed.connect(_on_reset_pressed)

func _load_settings_values() -> void:
	if check_shake:
		var s = SaveManager.data.get("settings", {})
		check_shake.button_pressed = bool(s.get("screen_shake", true))

func _on_play_pressed() -> void:
	if SoundManager.instance:
		SoundManager.instance.play_blip()
	var highest = int(SaveManager.data.get("highest_unlocked_level", 1))
	SaveManager.data["target_level"] = highest
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_levels_pressed() -> void:
	if SoundManager.instance:
		SoundManager.instance.play_blip()
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_reset_pressed() -> void:
	SaveManager.reset_save_data()
	_update_stats()
	_load_settings_values()
	if SoundManager.instance:
		SoundManager.instance.play_crash()

func _on_quit_pressed() -> void:
	get_tree().quit()
