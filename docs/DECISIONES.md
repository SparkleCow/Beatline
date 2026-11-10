# Registro de decisiones

Formato: decisión — por qué — consecuencias / cómo revertir.

## 2026-11-10 — Arranque del proyecto (hito 1)

### Entorno
- **Godot 4.7.2-stable** (última estable en GitHub al iniciar). Instalado fuera del repo en `C:\Users\Administrador\Tools\godot\`. Se usa el ejecutable `_console.exe` para headless porque imprime en la terminal. — Para continuar en otro PC: misma versión, y `GODOT=/ruta` o `godot` en el PATH.
- **Scripts `tools/godot.sh` y `tools/verify.sh`** (carpeta `tools/` no estaba en la estructura pedida). — Un único punto para encontrar Godot y siempre correrlo en headless; permite que `.claude/settings.json` autorice un comando estable en vez de una ruta absoluta de este PC.
- **Runner de tests propio** (`tests/run_tests.gd` + `base_test.gd`) en vez de GUT/gdUnit. — La regla es no agregar plugins sin preguntar. Si más adelante se quiere GUT, se puede migrar fácil (los tests son métodos `test_*`).
- **`.uid` de scripts se commitean.** — Godot 4.4+ los usa para referencias estables; ignorarlos rompe referencias entre clones.
- **`.gdignore` en `docs/`, `tools/` y `.claude/`** para que Godot no escanee esas carpetas.

### Renderizado y plataforma
- **Renderer Mobile** con `rendering_device/fallback_to_opengl3=true`; web usa Compatibility. — Pedido explícito; el fallback cubre teléfonos baratos con Vulkan defectuoso. El prototipo solo usa features presentes también en Compatibility, así que cambiar a Compatibility en todas las plataformas es trivial si el Mobile rinde mal en gama baja (riesgo anotado).
- **Viewport 1080x1920, stretch `canvas_items` + `expand`, ventana de PC 540x960, portrait.**
- **Cámara con `KEEP_WIDTH`** — en vertical, mantener el ancho garantiza que los 3 carriles siempre entren en pantalla en cualquier relación de aspecto.
- **MSAA apagado, sin sombras, materiales unshaded/per-vertex, niebla para ocultar la aparición lejana.** — Gama baja primero.

### Ritmo y audio
- **El reloj se basa en frames consumidos por el mezclador**, no en `get_playback_position()`. — Con `AudioStreamGenerator` la posición de reproducción no es fiable; en cambio sabemos exactamente cuántos frames empujamos y cuántos siguen en cola (`capacidad - get_frames_available()`). `song_time = mezclados + time_since_last_mix - output_latency`, forzado a ser monótono.
- **Respaldo a reloj de pared** (`Time.get_ticks_usec`, absoluto, no delta acumulado) si el audio no avanza en 0,5 s (dispositivo sin salida de audio). Se avisa con `push_warning` y el overlay muestra `WALL_CLOCK`.
- **Loop pre-renderizado + `AudioStreamGenerator`.** — Sintetizar muestra a muestra en GDScript cada frame es caro en gama baja. Se sintetiza cada voz una vez, se arma un loop de 2 compases al arrancar (una vez por semilla; reiniciar no re-renderiza) y en juego solo se copian bloques con `push_buffer`.
- **Mix rate 22050 Hz** para el hito 1 — la mitad de costo de render; suficiente para batería. Revisar en el hito 2 (melodía/hi-hats brillantes pueden pedir 44100).
- **Bombo en cada beat (four-on-the-floor) siempre.** — El pulso debe ser inequívoco para que el jugador sincronice; la variedad va en hi-hats, bombos extra y redobles.
- **BPM elegido de una lista fija** (110–140 en pasos de 5) en `MusicConfig`.
- Deriva teórica: la duración del loop se redondea a frames enteros (error ≤ 0,5 frame por loop ≈ 3 ms en 10 min a 22050 Hz). Aceptable; el reloj sigue al audio real igualmente.

### Semilla
- **FNV-1a 32 bits sobre "AAAA-MM-DD" (UTC)**, implementado a mano. — No depende de `String.hash()` ni de detalles del motor, así que es idéntico en todas las plataformas y versiones. Tests con valores de referencia calculados fuera de Godot.
- **Sub-semillas por sistema** (`derive(semilla, "music")`, `derive(semilla, "level")`). — Cambiar la música no altera el nivel y viceversa.
- **`RandomNumberGenerator` (PCG32) con semilla** para toda la generación. Riesgo: si Godot cambiara el algoritmo de `randi_range`/`randf` entre versiones, el nivel del día podría diferir entre versiones del juego. Mitigación futura: PRNG propio si se detecta.
- Forzar semilla: `DailySeed.force_seed()` o argumentos `-- --seed=N` / `-- --date=AAAA-MM-DD`.

### Nivel
- **El mundo se mueve hacia el jugador; el jugador no avanza en Z.** — Evita problemas de precisión de coma flotante en partidas largas y simplifica todo a `z = (song_time - hit_time) * velocidad`.
- **Velocidad = `units_per_beat * bpm / 60`.** — La distancia entre obstáculos de un beat es constante en pantalla sin importar el tempo; los tempos rápidos se sienten más rápidos.
- **Lógica del nivel separada en `LevelPattern`** (RefCounted pura) — testeable sin escena. `ObstacleSpawner` solo la ejecuta.
- **Modelo de "camino posible":** conjunto de carriles alcanzables entre filas, cambiando como máximo `floor((dt - solapamiento) / max(lane_change_time, min_time_per_lane_move))` carriles; las barreras bajas solo cuentan como pasables si `dt ≥ duración_salto + margen`. Si una fila deja el conjunto vacío, se abre un carril alcanzable al azar. Se exige `min_time_per_lane_move = 0,25 s` por carril (más que la animación de 0,11 s) para dejar margen humano.
- **Tiempo mínimo de reacción 0,45 s** entre filas y separación mínima de 1 beat; contratiempos (medio beat) solo después del 50 % de la rampa de dificultad.
- **Colisiones por AABB manual**, sin motor de física. — Más barato y determinista; tolerancia lateral del 85 % para perdonar roces.
- **Test de piloto automático**: un bot planifica la ruta con programación dinámica y juega con el spawner y el jugador reales; si el nivel es posible no debe chocar. Hay además un control negativo (quieto debe chocar).
- **Pooling**: obstáculos (48) y segmentos de pista pre-instanciados; si el pool se agota se amplía con advertencia (no debería pasar).

### Jugador e input
- **Cambio de carril y salto evaluados con `song_time`**, igual que los obstáculos. — Colisión coherente con la música aunque haya tirones.
- **Swipe dispara durante el arrastre** (no al soltar) y se re-arma para encadenar carriles; **toque corto al soltar = salto**; **swipe hacia arriba = salto inmediato** (sin la latencia de esperar a soltar).
- **Buffer de salto de 0,12 s** al aterrizar.
- **Acciones de teclado registradas en código** (`InputHandler.ensure_actions`) en vez de en `project.godot`. — Evita serializar eventos a mano; se pueden mover al InputMap del editor sin cambiar el resto.
- **El ratón emula toques** (`emulate_touch_from_mouse`) para probar el swipe en PC.

### Flujo
- **Arranca jugando directamente** (sin menú) con 8 beats de calentamiento. — Prototipo enfocado en probar la diversión.
- **Muerte congela el mundo y corta la música**; reinicio con toque/espacio tras 0,3 s de bloqueo (evita reinicios accidentales). Reinicio: no se re-renderiza audio ni se instancian nodos; < 1 s.
- **Mejor puntaje solo en memoria** en el hito 1; la persistencia llega con el hito 4.
- **Overlay de depuración visible por defecto** (F3 lo alterna), refrescado a 10 Hz.

### Claude Code
- Permisos en `.claude/settings.json` verificados contra la documentación oficial (sintaxis `Bash(cmd *)`, `Read(./ruta)`, precedencia deny > ask > allow). Se incluyen equivalentes `PowerShell(...)` porque en Windows Claude Code también usa PowerShell.
- Comandos personalizados en `.claude/commands/*.md` (siguen soportados; equivalen a skills). Subagente `revisor` con herramientas `Read, Grep, Glob` (solo lectura).
