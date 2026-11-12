---
description: Crea un sistema nuevo (escena + script + test) siguiendo las convenciones del proyecto
argument-hint: <nombre_en_snake_case> [carpeta: core|level|player|audio|ui]
allowed-tools: Read Glob Grep Write Edit Bash(./tools/verify.sh *) Bash(./tools/godot.sh *)
---

Crea el sistema `$0` en la carpeta de scripts `$1` (si no se indicó carpeta, elige la más adecuada entre `core`, `level`, `player`, `audio`, `ui` y explica por qué).

Sigue CLAUDE.md al pie de la letra:

1. **Script** `scripts/<carpeta>/$0.gd`:
   - `class_name` en PascalCase derivado de `$0`, `extends` el nodo mínimo necesario.
   - Comentario `##` de cabecera explicando su responsabilidad (una sola).
   - GDScript tipado, constantes con nombre, sin números mágicos (si hay parámetros ajustables, agrégalos a un recurso de `scripts/config/` o crea uno nuevo con su `.tres` en `resources/`).
   - Comunicación por **señales**; nada de `get_node` hacia otros sistemas. Si depende del ritmo, expone un `on_tick(song_time: float)` para conectarlo a `RhythmClock.tick`.
   - Separa la lógica pura (funciones `static` o una clase `RefCounted`) para que sea testeable sin escena.
2. **Escena** `scenes/<carpeta_de_escena>/$0.tscn` (formato `[gd_scene format=3]`) con el nodo raíz usando el script. Si el sistema vive dentro de `game.tscn`, agrégalo ahí en vez de crear escena aparte y dilo.
3. **Test** `tests/test_$0.gd` que extienda `"res://tests/base_test.gd"`, con métodos `test_*` que cubran la lógica pura (casos normales y bordes).
4. Si hay cableado necesario, hazlo en `GameManager._connect_signals()` o `main.gd`.
5. Ejecuta `./tools/verify.sh` y corrige hasta que pase.
6. Anota en `docs/DECISIONES.md` cualquier decisión no obvia.
7. Resume qué archivos creaste. No hagas commit (para eso está `/checkpoint`).
