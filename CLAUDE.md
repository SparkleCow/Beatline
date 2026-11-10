# Beatline — guía para Claude

## El juego
Runner rítmico 3D por carriles para móvil (vertical). El jugador avanza solo por una pista de neón de 3 carriles: desliza izq/der para cambiar de carril y toca para saltar. Los obstáculos llegan sincronizados con la música.

- **Gancho:** nivel diario. Una semilla derivada de la fecha UTC genera el nivel **y** la música del día; todos juegan lo mismo ese día.
- **Música procedural:** generada por código desde la semilla (bombo, caja, hi-hat, bajo, melodía; pentatónica / menor natural; 110–140 BPM). Cero música con derechos.
- **Estética (hito 3):** geométrica, neón sobre oscuro, glow, partículas, solo primitivas generadas por código.
- **Monetización (hito 6, NO antes):** rewarded para revivir, intersticial máx. cada 3–4 muertes, compra única sin anuncios.
- **Plataformas:** Android primero, luego web e iOS. Portrait, base 1080x1920.
- **Prioridad absoluta:** fluido en celulares de gama baja.

## Stack
- **Godot 4.7.2-stable** (instalado en este PC en `C:\Users\Administrador\Tools\godot\`, ejecutable de consola `Godot_v4.7.2-stable_win64_console.exe`). En otro PC: descargar la misma versión de https://github.com/godotengine/godot/releases/tag/4.7.2-stable y definir `GODOT=/ruta/al/ejecutable` o ponerlo en el PATH como `godot`.
- GDScript con tipado estático. Renderer **Mobile** (con fallback a OpenGL; web usa Compatibility).
- Git + Git LFS (audio, imágenes, fuentes, modelos). Trabajar en la rama `dev`.

## Estructura
| Carpeta | Para qué |
|---|---|
| `scenes/` | `main.tscn` (raíz), `game.tscn` (mundo 3D y sistemas), `ui/hud.tscn` |
| `scripts/core/` | `game_manager` (orquesta y cablea señales), `daily_seed`, `rhythm_clock`, `main` |
| `scripts/config/` | Clases `Resource` de configuración (`GameConfig`, `MusicConfig`, `DifficultyConfig`) |
| `scripts/level/` | `level_pattern` (lógica pura del nivel), `obstacle_spawner`, `obstacle`, `lane_track` |
| `scripts/player/` | `player_controller`, `input_handler` |
| `scripts/audio/` | `music_generator`, `synth_voices`, `drum_pattern` |
| `scripts/ui/` | `hud`, `debug_overlay` |
| `resources/` | Instancias `.tres` de configuración (tempos, escalas, dificultad, pista) |
| `assets/` | `audio/`, `fonts/`, `shaders/` (vacías por ahora) |
| `tests/` | Runner propio (`run_tests.gd`) + `test_*.gd` |
| `tools/` | `godot.sh` (Godot headless) y `verify.sh` (verificación completa) |
| `docs/` | `DECISIONES.md` (registro de decisiones), `ROADMAP.md` |

## Regla de oro: el ritmo manda
Toda aparición y posición de obstáculos se calcula desde el **reloj de audio** (`RhythmClock.song_time`, derivado de los frames que el mezclador ya consumió, compensando latencia). **Nunca** desde `_process` con delta acumulado.
- Posición de un obstáculo: `z = (song_time - hit_time) * velocidad`.
- Pista, jugador (cambio de carril, salto) y colisiones también se evalúan con `song_time` vía la señal `RhythmClock.tick`.
- Si agregas algo que deba ir a tiempo con la música, conéctalo a `tick`/`beat`/`bar`.

## Convenciones de código
- GDScript **tipado** siempre (`var x: int`, retornos `-> void`). El proyecto avisa con `untyped_declaration`.
- `snake_case` para archivos, funciones y variables; `PascalCase` para `class_name`; `CONSTANTES_EN_MAYÚSCULAS`.
- Un script por responsabilidad. La lógica pura (testeable sin escena) va separada de los nodos (ej. `LevelPattern` vs `ObstacleSpawner`).
- **Señales** entre sistemas, no referencias directas. Solo `GameManager` / `main.gd` cablean.
- **Nada de números mágicos:** constantes con nombre o campos en los recursos de configuración.
- Rendimiento móvil: pools pre-instanciados (nunca `instantiate`/`queue_free` en partida), materiales y meshes compartidos, sin sombras, sin física para colisiones (AABB manual), nada de trabajo pesado por frame en GDScript.
- Ojo: los `Packed*Array` se pasan **por copia** a funciones en Godot 4.
- Comentarios y textos de UI en español.
- Commits pequeños con Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`).
- Cada decisión no obvia se anota en `docs/DECISIONES.md`.

## Cómo correr y verificar
```bash
# Verificación completa: importa, corre tests y un smoke test de la escena (exit != 0 si falla)
./tools/verify.sh

# Solo tests
./tools/godot.sh -s res://tests/run_tests.gd

# Importar (necesario en un clon nuevo antes de correr tests: genera la caché de class_name)
./tools/godot.sh --import

# Correr la escena principal N frames en headless con semilla fija
./tools/godot.sh --quit-after 300 -- --seed=12345
```
`tools/godot.sh` agrega `--headless --path <repo>` y busca Godot en `$GODOT`, el PATH o la ruta de instalación de arriba.
Para jugar con ventana: abrir el proyecto en el editor de Godot 4.7.2 y pulsar F5.
Comandos de proyecto: `/verificar`, `/nuevo-sistema <nombre>`, `/checkpoint`. Subagente `revisor` para revisión de solo lectura.

## Qué NO hacer
- No agregar plugins, addons ni assets externos sin preguntar.
- No tocar monetización (AdMob, compras) hasta el hito 6.
- No usar música ni samples con derechos: todo el audio se sintetiza por código.
- No hacer `git push` ni crear remotos: lo hace el dueño del repo.
- No calcular tiempos de gameplay con delta acumulado (ver regla de oro).
- No leer `.env` ni `secrets/`.
