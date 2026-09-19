class_name ScoreManager
extends Node

signal score_updated(current_score: int, combo_mult: int)
signal combo_updated(combo_count: int, combo_timer: float)
signal combo_broken()

@export var score: int = 0
@export var combo_multiplier: int = 1
@export var combo_timeout: float = 4.5

var current_combo_timer: float = 0.0
var best_combo: int = 1
var total_close_calls: int = 0

func _process(delta: float) -> void:
	if combo_multiplier > 1:
		current_combo_timer -= delta
		combo_updated.emit(combo_multiplier, current_combo_timer)
		if current_combo_timer <= 0.0:
			reset_combo()

var _accumulated_score: float = 0.0

func add_survival_score(delta: float, is_high_speed: bool = false) -> void:
	var base_pts = 10.0 * delta
	if is_high_speed:
		base_pts *= 1.5
	_accumulated_score += base_pts * combo_multiplier
	if _accumulated_score >= 1.0:
		var pts = int(_accumulated_score)
		score += pts
		_accumulated_score -= float(pts)
		score_updated.emit(score, combo_multiplier)

func add_points(points: int) -> void:
	score += points * combo_multiplier
	score_updated.emit(score, combo_multiplier)

func register_close_call() -> void:
	total_close_calls += 1
	combo_multiplier = min(10, combo_multiplier + 1)
	current_combo_timer = combo_timeout
	best_combo = max(best_combo, combo_multiplier)
	add_points(250)
	combo_updated.emit(combo_multiplier, current_combo_timer)

func reset_combo() -> void:
	if combo_multiplier > 1:
		combo_multiplier = 1
		current_combo_timer = 0.0
		combo_broken.emit()
		score_updated.emit(score, combo_multiplier)

func reset_score() -> void:
	score = 0
	_accumulated_score = 0.0
	combo_multiplier = 1
	current_combo_timer = 0.0
	score_updated.emit(score, combo_multiplier)
