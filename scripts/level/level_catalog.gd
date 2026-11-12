class_name LevelCatalog
extends RefCounted
## Niveles fijos ("campaña"): semilla y dificultad establecidas, con meta en compases.
## Son duros a propósito y cada uno aprieta una mecánica distinta. Parten de la dificultad
## Difícil y solo cambian lo que los distingue, así siguen pasando por el mismo generador
## (y por su garantía de camino posible).

const BASE_DIFFICULTY: String = "res://resources/difficulty_hard.tres"
const BEATS_PER_BAR: int = 4


class Stage:
	extends RefCounted
	var title: String
	var seed_value: int
	var difficulty: DifficultyConfig
	## Compases a sobrevivir para superar el nivel.
	var goal_bars: int

	func _init(p_title: String, p_seed: int, p_difficulty: DifficultyConfig, p_goal_bars: int) -> void:
		title = p_title
		seed_value = p_seed
		difficulty = p_difficulty
		goal_bars = p_goal_bars

	func goal_beats() -> int:
		return goal_bars * LevelCatalog.BEATS_PER_BAR


static var _stages: Array[Stage] = []


static func stages() -> Array[Stage]:
	if not _stages.is_empty():
		return _stages
	_stages.append(Stage.new("ABISMO.EXE", 404404, _variant("Abismo", {
		&"gap_probability": 0.3, &"long_gap_probability": 0.45, &"platform_probability": 0.0,
		&"low_probability": 0.7, &"full_gap_probability": 0.2, &"mover_probability": 0.1,
	}), 40))
	_stages.append(Stage.new("ESCALERA.DLL", 808080, _variant("Escalera", {
		&"gap_probability": 0.1, &"long_gap_probability": 0.1, &"platform_probability": 0.6,
		&"low_probability": 0.7, &"jump_gate_probability": 0.3,
	}), 40))
	_stages.append(Stage.new("SIN_RIEL.SYS", 131313, _variant("Sin riel", {
		&"open_edge_probability": 0.85, &"mover_probability": 0.6, &"double_block_start": 0.8,
	}), 48))
	_stages.append(Stage.new("RAMPA.COM", 777000, _variant("Rampa", {
		&"ramp_gate_probability": 0.3, &"full_gap_probability": 0.12, &"long_gap_probability": 0.3,
	}), 48))
	_stages.append(Stage.new("KERNEL_PANIC", 666999, _variant("Kernel panic", {
		&"start_density": 1.0, &"max_density": 1.0, &"ramp_bars": 8, &"min_reaction_time": 0.3,
		&"min_time_per_lane_move": 0.16, &"offbeat_unlock_progress": 0.0, &"offbeat_probability": 0.6,
		&"mover_probability": 0.45, &"long_gap_probability": 0.3, &"open_edge_probability": 0.6,
		&"ramp_gate_probability": 0.1, &"full_gap_probability": 0.1,
	}), 64))
	# Cada nivel tiene su pista y su fondo.
	var music: Array[String] = ["glutton_120bpm", "darkness_road_165bpm", "glutton_120bpm",
			"darkness_road_remake_165bpm", "darkness_road_165bpm"]
	var skies: Array[int] = [1, 4, 2, 0, 3]
	for i: int in _stages.size():
		TrackLibrary.assign(DailySeed.derive(_stages[i].seed_value, DailySeed.SALT_MUSIC), music[i])
		SkyPresets.assign(_stages[i].seed_value, skies[i])
	return _stages


static func _variant(display_name: String, overrides: Dictionary[StringName, Variant]) -> DifficultyConfig:
	var config: DifficultyConfig = (load(BASE_DIFFICULTY) as DifficultyConfig).duplicate() as DifficultyConfig
	config.display_name = display_name
	for key: StringName in overrides:
		config.set(key, overrides[key])
	return config
