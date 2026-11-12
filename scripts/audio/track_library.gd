class_name TrackLibrary
extends RefCounted
## Catálogo de pistas de música pregrabadas (.ogg) en res://assets/audio/music/.
##
## Convención: el nombre termina en `_<BPM>bpm.ogg` (ej. `neon_requiem_132bpm.ogg`). El BPM
## debe ser exacto, la pista debe empezar en el primer beat y durar un número entero de
## compases (se reproduce en loop): los obstáculos se sincronizan con ese tempo.
## Si no hay pistas, el juego usa la música procedural (MusicGenerator).

const MUSIC_DIR: String = "res://assets/audio/music"
const EXTENSION: String = ".ogg"
## En un juego exportado los archivos originales no existen: se listan sus `.import`.
const IMPORT_SUFFIX: String = ".import"
const BPM_SUFFIX: String = "bpm"
const MIN_BPM: float = 60.0
const MAX_BPM: float = 220.0


class Track:
	extends RefCounted
	var path: String
	var title: String
	var bpm: float

	func _init(p_path: String, p_title: String, p_bpm: float) -> void:
		path = p_path
		title = p_title
		bpm = p_bpm


static var _cache: Array[Track] = []
static var _scanned: bool = false
## Semillas musicales con pista fija (niveles establecidos): semilla -> nombre sin extensión.
static var _assigned: Dictionary[int, String] = {}


## Fija la pista de una semilla musical (si el archivo no existe, se elige por semilla).
static func assign(music_seed: int, base_name: String) -> void:
	_assigned[music_seed] = base_name


## Pistas válidas, ordenadas por nombre (orden estable = misma pista para la misma semilla).
static func tracks() -> Array[Track]:
	if _scanned:
		return _cache
	_scanned = true
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(MUSIC_DIR)
	if dir == null:
		return _cache
	for file: String in dir.get_files():
		var name: String = file.trim_suffix(IMPORT_SUFFIX)
		if name.ends_with(EXTENSION) and not names.has(name):
			names.append(name)
	names.sort()
	for name: String in names:
		var bpm: float = parse_bpm(name)
		if bpm <= 0.0:
			push_warning("TrackLibrary: '%s' no indica el BPM (usa nombre_128bpm.ogg); se ignora." % name)
			continue
		_cache.append(Track.new(MUSIC_DIR.path_join(name), title_of(name), bpm))
	return _cache


## Pista que le toca a una semilla (la misma para todos ese día), o null si no hay pistas.
static func pick(music_seed: int) -> Track:
	var all: Array[Track] = tracks()
	if all.is_empty():
		return null
	if _assigned.has(music_seed):
		for track: Track in all:
			if track.path.get_file().get_basename() == _assigned[music_seed]:
				return track
	return all[posmod(music_seed, all.size())]


## BPM declarado en el nombre de archivo, o 0 si no lo indica o está fuera de rango.
static func parse_bpm(file_name: String) -> float:
	var base: String = file_name.get_basename().to_lower()
	if not base.ends_with(BPM_SUFFIX):
		return 0.0
	var number: String = base.trim_suffix(BPM_SUFFIX).get_slice("_", base.count("_"))
	if not number.is_valid_float():
		return 0.0
	var bpm: float = number.to_float()
	return bpm if bpm >= MIN_BPM and bpm <= MAX_BPM else 0.0


## Título legible: nombre sin el sufijo de BPM, con espacios y en mayúsculas.
static func title_of(file_name: String) -> String:
	var base: String = file_name.get_basename()
	var cut: int = base.rfind("_")
	if cut > 0 and parse_bpm(file_name) > 0.0:
		base = base.substr(0, cut)
	return base.replace("_", " ").to_upper()
