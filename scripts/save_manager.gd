class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://save_data.json"

static var data: Dictionary = {
	"highest_unlocked_level": 1,
	"completed_levels": [],
	"best_scores": {},
	"best_times": {},
	"stars": {},
	"settings": {
		"sfx_volume": 1.0,
		"music_volume": 1.0,
		"screen_shake": true
	}
}

static var _is_loaded: bool = false

static func load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		reset_save_data()
		_is_loaded = true
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		reset_save_data()
		_is_loaded = true
		return

	var json_str = file.get_as_text()
	file.close()

	var test_json = JSON.new()
	var err = test_json.parse(json_str)
	if err == OK and test_json.data is Dictionary:
		var loaded_dict = test_json.data as Dictionary
		# Merge safely
		for k in data.keys():
			if loaded_dict.has(k):
				data[k] = loaded_dict[k]
	else:
		reset_save_data()

	_is_loaded = true

static func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("Failed to open save file for writing: ", SAVE_PATH)
		return

	var json_str = JSON.stringify(data, "\t")
	file.store_string(json_str)
	file.close()

static func ensure_loaded() -> void:
	if not _is_loaded:
		load_save_data()

static func is_level_unlocked(lvl: int) -> bool:
	ensure_loaded()
	var highest = int(data.get("highest_unlocked_level", 1))
	return lvl <= highest

static func is_level_completed(lvl: int) -> bool:
	ensure_loaded()
	var completed = data.get("completed_levels", [])
	return completed.has(lvl)

static func record_level_completion(lvl: int, score: int, time: float, stars: int) -> void:
	ensure_loaded()
	var lvl_str = str(lvl)

	var completed: Array = data.get("completed_levels", [])
	if not completed.has(lvl):
		completed.append(lvl)
	data["completed_levels"] = completed

	# Unlock next level in strict chain
	var current_highest = int(data.get("highest_unlocked_level", 1))
	if lvl + 1 > current_highest and lvl < 100:
		data["highest_unlocked_level"] = lvl + 1

	# Best Score
	var best_scores: Dictionary = data.get("best_scores", {})
	var prev_best = int(best_scores.get(lvl_str, 0))
	if score > prev_best:
		best_scores[lvl_str] = score
	data["best_scores"] = best_scores

	# Best Time
	var best_times: Dictionary = data.get("best_times", {})
	var prev_time = float(best_times.get(lvl_str, 999999.0))
	if time < prev_time:
		best_times[lvl_str] = time
	data["best_times"] = best_times

	# Stars
	var star_dict: Dictionary = data.get("stars", {})
	var prev_stars = int(star_dict.get(lvl_str, 0))
	if stars > prev_stars:
		star_dict[lvl_str] = stars
	data["stars"] = star_dict

	save_game()

static func get_level_stars(lvl: int) -> int:
	ensure_loaded()
	var star_dict: Dictionary = data.get("stars", {})
	return int(star_dict.get(str(lvl), 0))

static func get_level_best_score(lvl: int) -> int:
	ensure_loaded()
	var best_scores: Dictionary = data.get("best_scores", {})
	return int(best_scores.get(str(lvl), 0))

static func reset_save_data() -> void:
	data = {
		"highest_unlocked_level": 1,
		"completed_levels": [],
		"best_scores": {},
		"best_times": {},
		"stars": {},
		"settings": {
			"sfx_volume": 1.0,
			"music_volume": 1.0,
			"screen_shake": true
		}
	}
	save_game()
