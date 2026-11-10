# Beatline

Runner rítmico 3D por carriles para móvil. Avanzas solo por una pista de 3 carriles: desliza para cambiar de carril y toca para saltar; los obstáculos llegan al ritmo de la música. Cada día UTC hay **un nivel y una canción nuevos, iguales para todo el mundo**, generados por código desde una semilla basada en la fecha. Sin música con derechos de autor: todo el audio se sintetiza.

> Estado: **hito 1 — prototipo gris** (cubos grises + batería procedural). Ver [docs/ROADMAP.md](docs/ROADMAP.md).

## Requisitos
- **Godot 4.7.2-stable** (estándar, no .NET): https://github.com/godotengine/godot/releases/tag/4.7.2-stable
- Git y Git LFS (`git lfs install`).
- Para los scripts de `tools/`: una shell bash (en Windows sirve Git Bash).

## Abrir y jugar
1. Abre Godot 4.7.2 → **Importar** → selecciona `project.godot` de esta carpeta.
2. Pulsa **F5** (o el botón ▶).

Controles en PC: **← →** o **A/D** cambian de carril, **Espacio / ↑ / W** salta, **F3** muestra/oculta el overlay de depuración. Con el ratón: arrastrar horizontal = carril, clic corto o arrastrar hacia arriba = salto. Tras morir, toca o pulsa Espacio para reintentar.

Forzar una semilla o fecha (depuración), desde la terminal:
```bash
godot --path . -- --seed=12345
godot --path . -- --date=2026-12-31
```

## Verificar (headless)
```bash
./tools/verify.sh                          # importa, corre tests y un smoke test de la escena
./tools/godot.sh -s res://tests/run_tests.gd   # solo tests
```
`tools/godot.sh` busca Godot en la variable `GODOT`, luego `godot`/`godot4` en el PATH y luego `~/Tools/godot/Godot_v4.7.2-stable_win64_console.exe`.

## Estructura
```
project.godot
scenes/          main.tscn, game.tscn, ui/hud.tscn
scripts/
  core/          game_manager, daily_seed, rhythm_clock, main
  config/        clases Resource de configuración
  level/         level_pattern, lane_track, obstacle_spawner, obstacle
  player/        player_controller, input_handler
  audio/         music_generator, synth_voices, drum_pattern
  ui/            hud, debug_overlay
resources/       configuración .tres (juego, música, dificultad)
assets/          audio/, fonts/, shaders/
tests/           runner propio + test_*.gd
tools/           godot.sh, verify.sh
docs/            DECISIONES.md, ROADMAP.md
```

Guía para trabajar con Claude Code: [CLAUDE.md](CLAUDE.md).
