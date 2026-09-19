class_name HeatManager
extends Node

signal heat_changed(new_heat: int, current_exp: float, max_exp: float)

@export var current_heat: int = 1
@export var max_heat: int = 10
@export var heat_exp: float = 0.0
@export var base_exp_per_heat: float = 100.0
@export var exp_growth: float = 1.35

# Rate at which heat naturally increases per second of survival
@export var survival_exp_rate: float = 6.0

func _ready() -> void:
	current_heat = 1
	heat_exp = 0.0
	emit_heat_update()

func get_exp_for_current_heat() -> float:
	return base_exp_per_heat * pow(exp_growth, current_heat - 1)

func add_heat_exp(amount: float) -> void:
	heat_exp += amount
	var needed = get_exp_for_current_heat()
	while heat_exp >= needed and current_heat < max_heat:
		heat_exp -= needed
		current_heat += 1
		needed = get_exp_for_current_heat()
		emit_heat_update()
	emit_heat_update()

func reduce_heat(amount_levels: int = 1) -> void:
	current_heat = max(1, current_heat - amount_levels)
	heat_exp = 0.0
	emit_heat_update()

func emit_heat_update() -> void:
	heat_changed.emit(current_heat, heat_exp, get_exp_for_current_heat())

func process_survival(delta: float, heat_rate_mult: float = 1.0) -> void:
	add_heat_exp(survival_exp_rate * heat_rate_mult * delta)
