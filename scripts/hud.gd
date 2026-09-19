class_name HUD
extends CanvasLayer

signal next_level_pressed()
signal retry_pressed()
signal level_select_pressed()
signal main_menu_pressed()
signal resume_pressed()

# Top Left
@onready var score_label: Label = $TopLeft/Panel/VBox/ScoreLabel
@onready var world_label: Label = $TopLeft/Panel/VBox/WorldLabel
@onready var objective_label: Label = $TopLeft/Panel/VBox/ObjectiveLabel
@onready var objective_bar: ProgressBar = $TopLeft/Panel/VBox/ObjectiveBar

# Top Center
@onready var lives_container: HBoxContainer = $TopCenter/VBox/LivesContainer
@onready var shield_badge: PanelContainer = $TopCenter/VBox/ShieldBadge

# Top Right
@onready var minimap: Minimap = $TopRight/VBox/Minimap
@onready var destination_label: Label = $TopRight/VBox/DestinationLabel
@onready var heat_label: Label = $TopRight/VBox/HeatHBox/HeatLabel
@onready var energy_label: Label = $TopRight/VBox/HeatHBox/EnergyLabel
@onready var heat_bar: ProgressBar = $TopRight/VBox/HeatBar
@onready var combo_badge: PanelContainer = $TopRight/VBox/ComboBadge
@onready var combo_label: Label = $TopRight/VBox/ComboBadge/ComboLabel

# Bottom Left
@onready var nitro_bar: ProgressBar = $BottomLeft/VBox/NitroBar

# Bottom Center Alerts
@onready var center_alert: Control = $BottomCenter/CenterAlert
@onready var toast_label: Label = $BottomCenter/CenterAlert/ToastLabel
@onready var heat_warning_flash: ColorRect = $HeatWarningFlash

# Bottom Right
@onready var speed_label: Label = $BottomRight/Panel/VBox/SpeedLabel
@onready var time_label: Label = $BottomRight/Panel/VBox/TimeLabel

# Modals
@onready var backdrop_tint: ColorRect = $Modals/BackdropTint
@onready var win_modal: PanelContainer = $Modals/WinModal
@onready var win_stars_label: Label = $Modals/WinModal/VBox/StarsLabel
@onready var win_score_label: Label = $Modals/WinModal/VBox/ScoreLabel
@onready var win_time_label: Label = $Modals/WinModal/VBox/TimeLabel
@onready var win_close_calls_label: Label = $Modals/WinModal/VBox/CloseCallsLabel
@onready var win_best_score_label: Label = $Modals/WinModal/VBox/BestScoreLabel
@onready var btn_next_level: Button = $Modals/WinModal/VBox/ButtonContainer/NextLevelButton
@onready var btn_win_retry: Button = $Modals/WinModal/VBox/ButtonContainer/WinRetryButton
@onready var btn_win_select: Button = $Modals/WinModal/VBox/ButtonContainer/WinSelectButton

@onready var fail_modal: PanelContainer = $Modals/FailModal
@onready var fail_score_label: Label = $Modals/FailModal/VBox/ScoreLabel
@onready var fail_time_label: Label = $Modals/FailModal/VBox/TimeLabel
@onready var fail_heat_label: Label = $Modals/FailModal/VBox/MaxHeatLabel
@onready var fail_close_calls_label: Label = $Modals/FailModal/VBox/CloseCallsLabel
@onready var fail_best_score_label: Label = $Modals/FailModal/VBox/BestScoreLabel
@onready var btn_fail_retry: Button = $Modals/FailModal/VBox/ButtonContainer/FailRetryButton
@onready var btn_fail_select: Button = $Modals/FailModal/VBox/ButtonContainer/FailSelectButton
@onready var btn_fail_menu: Button = $Modals/FailModal/VBox/ButtonContainer/FailMenuButton

@onready var pause_modal: PanelContainer = $Modals/PauseModal
@onready var btn_pause_resume: Button = $Modals/PauseModal/VBox/ButtonContainer/ResumeButton
@onready var btn_pause_restart: Button = $Modals/PauseModal/VBox/ButtonContainer/RestartButton
@onready var btn_pause_select: Button = $Modals/PauseModal/VBox/ButtonContainer/PauseSelectButton
@onready var btn_pause_menu: Button = $Modals/PauseModal/VBox/ButtonContainer/PauseMenuButton
@onready var check_shake: CheckBox = $Modals/PauseModal/VBox/SettingsContainer/ShakeCheck

var _toast_tween: Tween
var _last_heat: int = 1
var _energy_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_modals()
	_connect_buttons()
	combo_badge.visible = false
	shield_badge.visible = false
	heat_warning_flash.visible = false
	toast_label.text = ""

func _connect_buttons() -> void:
	var buttons = [
		btn_next_level, btn_win_retry, btn_win_select,
		btn_fail_retry, btn_fail_select, btn_fail_menu,
		btn_pause_resume, btn_pause_restart, btn_pause_select, btn_pause_menu
	]
	for b in buttons:
		if is_instance_valid(b):
			b.mouse_entered.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip())

	if btn_next_level:
		btn_next_level.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); next_level_pressed.emit())
	if btn_win_retry:
		btn_win_retry.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); retry_pressed.emit())
	if btn_win_select:
		btn_win_select.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); level_select_pressed.emit())

	if btn_fail_retry:
		btn_fail_retry.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); retry_pressed.emit())
	if btn_fail_select:
		btn_fail_select.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); level_select_pressed.emit())
	if btn_fail_menu:
		btn_fail_menu.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); main_menu_pressed.emit())

	if btn_pause_resume:
		btn_pause_resume.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); resume_pressed.emit())
	if btn_pause_restart:
		btn_pause_restart.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); retry_pressed.emit())
	if btn_pause_select:
		btn_pause_select.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); level_select_pressed.emit())
	if btn_pause_menu:
		btn_pause_menu.pressed.connect(func(): if SoundManager.instance: SoundManager.instance.play_blip(); main_menu_pressed.emit())

	if check_shake:
		var s_dict = SaveManager.data.get("settings", {})
		check_shake.button_pressed = bool(s_dict.get("screen_shake", true))
		check_shake.toggled.connect(func(v):
			SaveManager.data.get("settings", {})["screen_shake"] = v
			SaveManager.save_game()
		)

func _hide_modals() -> void:
	if backdrop_tint:
		backdrop_tint.visible = false
	win_modal.visible = false
	fail_modal.visible = false
	pause_modal.visible = false

func set_level_info(lvl: int, world_title: String) -> void:
	var world_idx = int((lvl - 1) / 10) + 1
	world_label.text = "WORLD %02d // LEVEL %02d — %s" % [world_idx, lvl, world_title.to_upper()]

func update_objective_progress(cur_val: float, target_val: float, label_str: String) -> void:
	objective_label.text = label_str
	var pct = clamp(cur_val / max(0.001, target_val) * 100.0, 0.0, 100.0)
	objective_bar.value = pct

func update_score(score: int, _combo_mult: int) -> void:
	score_label.text = "%d" % score

func update_combo(combo_count: int, _combo_timer: float, _max_timer: float = 4.5) -> void:
	if combo_count > 1:
		combo_badge.visible = true
		combo_label.text = "ESCAPE x%d" % combo_count
		show_toast("ESCAPE CHAIN x%d" % combo_count, Color(1.0, 0.6, 0.1))
	else:
		combo_badge.visible = false

func notify_combo_broken() -> void:
	combo_badge.visible = false
	show_toast("COMBO LOST", Color(1.0, 0.3, 0.3))

func update_heat(heat: int, cur_exp: float, max_exp: float) -> void:
	heat_label.text = "HEAT %02d" % heat
	var pct = clamp(cur_exp / max(0.001, max_exp) * 100.0, 0.0, 100.0)
	heat_bar.value = pct

	# Color shift: heat 1-3 Cyan, 4-6 Yellow, 7-8 Orange, 9-10 Crimson
	if heat <= 3:
		heat_label.modulate = Color(0.0, 0.9, 1.0)
	elif heat <= 6:
		heat_label.modulate = Color(1.0, 0.85, 0.1)
	elif heat <= 8:
		heat_label.modulate = Color(1.0, 0.5, 0.1)
	else:
		heat_label.modulate = Color(1.0, 0.15, 0.25)

	if heat > _last_heat:
		_last_heat = heat
		show_toast("HEAT INCREASED!", Color(1.0, 0.25, 0.25))
		_flash_heat_warning()
	_last_heat = heat

func set_energy_pickups(count: int) -> void:
	_energy_count = count
	energy_label.text = "● %02d" % _energy_count

func update_destination_info(dist_m: float, arrow: String) -> void:
	if destination_label:
		destination_label.text = "DESTINATION: %dm %s" % [int(dist_m), arrow]

func _flash_heat_warning() -> void:
	heat_warning_flash.visible = true
	var tw = create_tween()
	tw.tween_property(heat_warning_flash, "modulate:a", 0.4, 0.12)
	tw.tween_property(heat_warning_flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): heat_warning_flash.visible = false)

func update_lives(remaining: int) -> void:
	var children = lives_container.get_children()
	for i in range(children.size()):
		var icon = children[i] as Label
		if i < remaining:
			icon.text = "♥"
			icon.modulate = Color(1.0, 0.2, 0.35, 1.0)
		else:
			icon.text = "♡"
			icon.modulate = Color(0.4, 0.45, 0.5, 0.3)

func update_shield(is_active: bool) -> void:
	shield_badge.visible = is_active
	if is_active:
		show_toast("SHIELD ACTIVE", Color(0.0, 1.0, 0.65))
	else:
		show_toast("SHIELD LOST", Color(1.0, 0.45, 0.2))

func update_speed(speed: float) -> void:
	var kmh = int(speed * 3.6)
	speed_label.text = "%3d KM/H" % kmh

func update_elapsed_time(seconds: float) -> void:
	time_label.text = "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func update_nitro(current_nitro: float, max_nitro: float) -> void:
	var pct = clamp(current_nitro / max_nitro * 100.0, 0.0, 100.0)
	nitro_bar.value = pct

func show_toast(msg: String, col: Color = Color.WHITE) -> void:
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	toast_label.text = msg
	toast_label.modulate = col
	center_alert.modulate.a = 1.0
	center_alert.scale = Vector2(1.25, 1.25)

	_toast_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(center_alert, "scale", Vector2.ONE, 0.12)
	_toast_tween.tween_interval(1.1)
	_toast_tween.tween_property(center_alert, "modulate:a", 0.0, 0.25)

func show_win_modal(stars: int, score: int, elapsed_time: float, close_calls: int, best_score: int, has_next_level: bool = true) -> void:
	_hide_modals()
	if backdrop_tint:
		backdrop_tint.visible = true
	win_modal.visible = true

	var star_str = ""
	for s in range(stars):
		star_str += "★ "
	for s in range(3 - stars):
		star_str += "☆ "
	win_stars_label.text = star_str

	win_score_label.text = "SCORE: %d" % score
	win_time_label.text = "TIME: %02d:%02d" % [int(elapsed_time) / 60, int(elapsed_time) % 60]
	win_close_calls_label.text = "CLOSE CALLS: %d" % close_calls
	win_best_score_label.text = "BEST SCORE: %d" % best_score

	if btn_next_level:
		btn_next_level.visible = has_next_level
		if has_next_level:
			btn_next_level.grab_focus()

func show_fail_modal(score: int, elapsed_time: float, max_heat: int, close_calls: int, best_score: int) -> void:
	_hide_modals()
	if backdrop_tint:
		backdrop_tint.visible = true
	fail_modal.visible = true
	fail_score_label.text = "FINAL SCORE: %d" % score
	fail_time_label.text = "SURVIVAL TIME: %02d:%02d" % [int(elapsed_time) / 60, int(elapsed_time) % 60]
	fail_heat_label.text = "MAX HEAT: %02d" % max_heat
	fail_close_calls_label.text = "CLOSE CALLS: %d" % close_calls
	fail_best_score_label.text = "BEST SCORE: %d" % best_score
	if btn_fail_retry:
		btn_fail_retry.grab_focus()

func show_pause_modal(paused: bool) -> void:
	if backdrop_tint:
		backdrop_tint.visible = paused
	pause_modal.visible = paused
	if paused and btn_pause_resume:
		btn_pause_resume.grab_focus()
