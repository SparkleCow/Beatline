class_name DebugOverlay
extends Label
## Overlay de depuración: BPM, beat, compás, semilla, FPS, reloj. Se alterna con F3.
## Se refresca a ~10 Hz (lo limita GameManager) para no re-maquetar texto cada frame.

const TEMPLATE: String = "BPM %d | beat %d | compás %d\nsemilla %d%s\nFPS %d | t %.2fs\nlatencia %.0f ms | reloj %s\nobstáculos %d"
const FORCED_TAG: String = " (forzada)"


func show_stats(stats: Dictionary) -> void:
	if not visible:
		return
	text = TEMPLATE % [
		int(stats["bpm"]),
		int(stats["beat"]),
		int(stats["bar"]),
		int(stats["seed"]),
		FORCED_TAG if bool(stats["forced_seed"]) else "",
		int(stats["fps"]),
		float(stats["song_time"]),
		float(stats["latency_ms"]),
		str(stats["clock_mode"]),
		int(stats["obstacles"]),
	]
