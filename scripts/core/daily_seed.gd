class_name DailySeed
extends RefCounted
## Semilla diaria determinista a partir de la fecha UTC.
##
## Mismo día UTC => misma semilla en cualquier dispositivo y plataforma.
## Se usa FNV-1a de 32 bits sobre el texto "AAAA-MM-DD" (no depende de String.hash()
## ni de detalles internos del motor, así que es estable entre versiones de Godot).
##
## Para depurar se puede forzar la semilla:
##   - Desde código: DailySeed.force_seed(1234)
##   - Línea de comandos: godot --path . -- --seed=1234   o   -- --date=2026-01-31

const FNV_OFFSET_BASIS: int = 2166136261
const FNV_PRIME: int = 16777619
const MASK_32: int = 0xFFFFFFFF
const ARG_SEED: String = "--seed="
const ARG_DATE: String = "--date="
const DATE_SEPARATOR: String = "-"
const DATE_PARTS: int = 3
const SECONDS_PER_DAY: int = 86400

const SALT_MUSIC: String = "music"
const SALT_LEVEL: String = "level"

static var _has_forced_seed: bool = false
static var _forced_seed: int = 0


## Clave de texto canónica para una fecha.
static func date_key(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]


## Hash FNV-1a de 32 bits (determinista, sin signo, en [0, 2^32)).
static func hash_string(text: String) -> int:
	var h: int = FNV_OFFSET_BASIS
	for b: int in text.to_utf8_buffer():
		h = ((h ^ b) * FNV_PRIME) & MASK_32
	return h


## Semilla para una fecha concreta.
static func seed_for_date(year: int, month: int, day: int) -> int:
	return hash_string(date_key(year, month, day))


## Semilla del día actual en UTC.
static func today_utc_seed() -> int:
	var d: Dictionary = Time.get_date_dict_from_system(true)
	return seed_for_date(int(d["year"]), int(d["month"]), int(d["day"]))


## Fecha UTC de hace `days_ago` días (0 = hoy) como diccionario {year, month, day}.
static func utc_date_days_ago(days_ago: int) -> Dictionary:
	var unix: int = int(Time.get_unix_time_from_system()) - days_ago * SECONDS_PER_DAY
	return Time.get_date_dict_from_unix_time(unix)


## Semilla del nivel de hace `days_ago` días (0 = hoy).
static func seed_for_days_ago(days_ago: int) -> int:
	var d: Dictionary = utc_date_days_ago(days_ago)
	return seed_for_date(int(d["year"]), int(d["month"]), int(d["day"]))


## Sub-semilla independiente para un sistema (música, nivel...). Cambiar un sistema
## no altera la secuencia aleatoria del otro.
static func derive(base_seed: int, salt: String) -> int:
	return hash_string("%d:%s" % [base_seed, salt])


static func force_seed(value: int) -> void:
	_has_forced_seed = true
	_forced_seed = value


static func clear_forced_seed() -> void:
	_has_forced_seed = false
	_forced_seed = 0


static func has_forced_seed() -> bool:
	return _has_forced_seed


## Semilla a usar: forzada por código > argumento --seed > argumento --date > hoy UTC.
static func current_seed() -> int:
	if _has_forced_seed:
		return _forced_seed
	return seed_from_args(OS.get_cmdline_user_args())


## Resuelve la semilla a partir de argumentos de usuario (lo que va después de "--").
static func seed_from_args(args: PackedStringArray) -> int:
	for arg: String in args:
		if arg.begins_with(ARG_SEED):
			var value: String = arg.substr(ARG_SEED.length())
			if value.is_valid_int():
				return value.to_int()
			push_warning("DailySeed: --seed inválido '%s', se ignora." % value)
		elif arg.begins_with(ARG_DATE):
			var parts: PackedStringArray = arg.substr(ARG_DATE.length()).split(DATE_SEPARATOR)
			if parts.size() == DATE_PARTS:
				return seed_for_date(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
			push_warning("DailySeed: --date inválido '%s', se ignora." % arg)
	return today_utc_seed()
