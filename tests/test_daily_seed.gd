extends "res://tests/base_test.gd"
## La semilla diaria debe ser determinista y estable entre plataformas.

## Valores de referencia calculados fuera de Godot (FNV-1a 32 bits).
const GOLDEN_2026_11_10: int = 1813764870
const GOLDEN_2026_01_01: int = 2049302883
const GOLDEN_LEVEL_2026_11_10: int = 1176440410
const DAYS_TO_CHECK: int = 366


func test_same_date_same_seed() -> void:
	assert_eq(DailySeed.seed_for_date(2026, 11, 10), DailySeed.seed_for_date(2026, 11, 10), "misma fecha")


func test_golden_values_cross_platform() -> void:
	assert_eq(DailySeed.seed_for_date(2026, 11, 10), GOLDEN_2026_11_10, "2026-11-10")
	assert_eq(DailySeed.seed_for_date(2026, 1, 1), GOLDEN_2026_01_01, "2026-01-01")
	assert_eq(DailySeed.derive(GOLDEN_2026_11_10, DailySeed.SALT_LEVEL), GOLDEN_LEVEL_2026_11_10, "derivada nivel")


func test_different_days_different_seeds() -> void:
	var seen: Dictionary = {}
	var start: int = int(Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00"))
	for i: int in DAYS_TO_CHECK:
		var d: Dictionary = Time.get_date_dict_from_unix_time(start + i * 86400)
		var s: int = DailySeed.seed_for_date(int(d["year"]), int(d["month"]), int(d["day"]))
		assert_false(seen.has(s), "colisión de semilla en día %d" % i)
		seen[s] = true


func test_seed_is_32_bit_non_negative() -> void:
	var s: int = DailySeed.seed_for_date(1999, 12, 31)
	assert_true(s >= 0 and s <= DailySeed.MASK_32, "rango 32 bits")


func test_derived_seeds_differ_by_salt() -> void:
	var base: int = DailySeed.seed_for_date(2026, 11, 10)
	assert_ne(DailySeed.derive(base, DailySeed.SALT_MUSIC), DailySeed.derive(base, DailySeed.SALT_LEVEL), "sal distinta")


func test_today_matches_utc_date() -> void:
	var d: Dictionary = Time.get_date_dict_from_system(true)
	assert_eq(DailySeed.today_utc_seed(), DailySeed.seed_for_date(int(d["year"]), int(d["month"]), int(d["day"])), "hoy UTC")


func test_forced_seed_overrides() -> void:
	DailySeed.force_seed(42)
	assert_eq(DailySeed.current_seed(), 42, "forzada")
	assert_true(DailySeed.has_forced_seed(), "flag forzada")
	DailySeed.clear_forced_seed()
	assert_false(DailySeed.has_forced_seed(), "flag limpia")


func test_seed_from_args() -> void:
	assert_eq(DailySeed.seed_from_args(PackedStringArray(["--seed=777"])), 777, "--seed")
	assert_eq(DailySeed.seed_from_args(PackedStringArray(["--date=2026-11-10"])), GOLDEN_2026_11_10, "--date")
	assert_eq(DailySeed.seed_from_args(PackedStringArray()), DailySeed.today_utc_seed(), "sin args")
