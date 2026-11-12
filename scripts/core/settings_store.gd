class_name SettingsStore
extends RefCounted
## Preferencias del jugador guardadas en user://settings.cfg (volumen, debug, dificultad).

const PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
const KEY_VOLUME: String = "volume"
const KEY_SFX_VOLUME: String = "sfx_volume"
const KEY_DEBUG: String = "show_debug"
const KEY_DIFFICULTY: String = "difficulty"
const DEFAULT_VOLUME: float = 0.9
const DEFAULT_SFX_VOLUME: float = 0.8
const DEFAULT_DIFFICULTY: int = 1
const MASTER_BUS: int = 0

var volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var show_debug: bool = false
var difficulty_index: int = DEFAULT_DIFFICULTY


static func load_or_default() -> SettingsStore:
	var s := SettingsStore.new()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		s.volume = float(cfg.get_value(SECTION, KEY_VOLUME, DEFAULT_VOLUME))
		s.sfx_volume = float(cfg.get_value(SECTION, KEY_SFX_VOLUME, DEFAULT_SFX_VOLUME))
		s.show_debug = bool(cfg.get_value(SECTION, KEY_DEBUG, false))
		s.difficulty_index = int(cfg.get_value(SECTION, KEY_DIFFICULTY, DEFAULT_DIFFICULTY))
	return s


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_VOLUME, volume)
	cfg.set_value(SECTION, KEY_SFX_VOLUME, sfx_volume)
	cfg.set_value(SECTION, KEY_DEBUG, show_debug)
	cfg.set_value(SECTION, KEY_DIFFICULTY, difficulty_index)
	var err: Error = cfg.save(PATH)
	if err != OK:
		push_warning("SettingsStore: no se pudo guardar (%s)." % error_string(err))


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(maxf(volume, 0.0001)))
	SfxPlayer.ensure_bus()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SfxPlayer.BUS_NAME),
			linear_to_db(maxf(sfx_volume, 0.0001)))
