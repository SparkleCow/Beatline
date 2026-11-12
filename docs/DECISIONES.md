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

## 2026-11-10 — Pase neón Y2K + darkwave (adelanto de hitos 2 y 3)
Pedido del dueño: luces neón ligeras, más rápido, música más fuerte y electrónica (darkwave), más obstáculos, mucho color y fondo Y2K.
- **Fondo Y2K 100 % procedural** (shader en un quad hijo de la cámara: degradado, sol synthwave a franjas, destellos ✦ titilando, scanlines) en vez de GIFs. — Los GIFs serían assets externos (regla: preguntar), Godot no los reproduce nativamente y pesan; el shader es un solo draw call y cero memoria de texturas.
- **Glow del WorldEnvironment** (umbral HDR 0,9, niveles 1–4) + materiales unshaded con color > 1. — Un único post-proceso barato da todo el brillo; nada de luces dinámicas ni sombras.
- **Variables globales de shader** (`beat_pulse`, `world_scroll`, `bar_index` en `[shader_globals]`) que actualiza `NeonFx` desde `RhythmClock.tick`. — Todos los materiales laten con el beat sin tocar cada material ni usar delta. Funcionan también en Compatibility (web).
- **Colores por compás**: cada compás de obstáculos usa un color de `NeonPalette` (rosa, cian, morado, lima, naranja); un material compartido por color y tipo (10 en total). No se usan `instance uniform` por compatibilidad con web.
- **Obstáculos estilo wireframe/Tron** (aristas brillantes calculadas en el shader desde la posición local) y barreras bajas con franjas.
- **Pista**: grilla neón en shader (sin mallas divisorias), rieles cian, un arco por segmento (rosa/morado alternados) y suelo synthwave infinito alrededor.
- **Partículas CPU** (estela del jugador y explosión al morir). Son solo visuales: usan delta interno, no afectan la jugabilidad. CPUParticles por compatibilidad con gama baja y web.
- **Golpe de FOV** de 3° en cada beat.
- **Música darkwave**: bajo de dos sierras desafinadas con filtro de envolvente (corcheas o galope), arpegio de pulso con eco de corchea con puntillo, progresiones en menor natural (i–VI–III–VII y similares) un acorde por compás, caja "gated" ochentera, loop de 4 compases, saturación suave `tanh` y volumen 0 dB. Notas cacheadas por altura: el render del loop tarda ~220 ms en PC (vigilar en gama baja; mover a hilo en el hito 2 si hace falta).
- **Tempo 120–140 BPM** (antes 110–140) y **velocidad 9 unidades/beat** (antes 7). — "Más movido". Sigue dentro del rango pedido.
- **Más obstáculos**: densidad 0,55→0,9, doble bloqueo 0,6, contratiempos desde el 30 % de la rampa, rampa en 32 compases, calentamiento de 4 beats. Las garantías de camino posible y reacción mínima no cambian (tests y piloto automático siguen pasando).

## 2026-11-10 — Menú y patrones más difíciles
- **Menú construido por código** (`MainMenu` + `NeonTheme`), sin assets: botones con borde y halo neón, título que late al BPM del nivel elegido. El mundo 3D del día se ve quieto detrás (el sol y los destellos siguen animados por el shader).
- **Selector de nivel**: HOY, días anteriores (hasta 30, ◀ va hacia atrás en el tiempo) y ALEATORIO (`randi()`). No se permiten días futuros. Muestra BPM y semilla antes de jugar (el BPM es la primera tirada del RNG musical, así que calcularlo es instantáneo).
- **Dificultades como recursos** (`difficulty_easy.tres`, `difficulty_config.tres` = Normal, `difficulty_hard.tres`). La semilla es la misma en todas, pero el patrón cambia con la dificultad: un ranking diario futuro debe separarse por dificultad.
- **Preferencias en `user://settings.cfg`** (volumen del bus Master, debug, dificultad) con `SettingsStore`.
- **Pantalla de muerte con REINTENTAR y MENÚ**; los botones no toman foco para que Espacio/toque siga reintentando al instante.
- **Patrones nuevos**: *puerta de salto* (muros en todos los carriles menos uno con barrera baja, preferentemente el centro: hay que saltar sí o sí) y *barrera baja completa* (3 carriles). El hueco de la puerta siempre cae en un carril alcanzable, así que la garantía de camino se mantiene. Las filas de un solo bloque son minoría desde el inicio (`double_block_start`).
- **Normal más difícil**: densidad 0,7→0,95, reacción mínima 0,40 s, 0,22 s por carril. Difícil: 0,34 s y 0,18 s. Tests: el validador y el piloto automático pasan en las 3 dificultades.
- **Ventana de PC 405×720** (antes 540×960): en pantallas de 768 px de alto Windows recortaba la ventana y, con `stretch aspect = expand`, el lienzo se ensanchaba y la UI se salía de los bordes. En el celular no afecta (pantalla completa).

## 2026-11-10 — Refactor Y2K: cámara estable, salto variable, terreno, niveles fijos, UI y audio
Pedido del dueño: quitar el latido de cámara, más mecánicas y dificultad sin reescribir la base, niveles establecidos y duros, UI Y2K más interesante, pistas .ogg estilo darkwave/EBM y SFX.
- **Cámara sin latido.** Se eliminó el golpe de FOV por beat de `NeonFx` (era el "zoom" repetitivo). `CameraRig` solo traslada la cámara siguiendo al cubo con suavizado exponencial; FOV y orientación fijos. Usa delta porque es puramente visual (igual que las partículas).
- **Se amplió el modelo de filas, no se reemplazó.** `LevelPattern.Kind` suma GAP, LONG_GAP, PLATFORM, RAMP y MOVER. Las filas ganan `head`/`tail` (segundos que la fila ocupa antes/después de su beat) para que los objetos largos sigan dentro de la garantía de camino. El generador decide con el peor `head` posible; el validador y el piloto automático usan el real.
- **Salto balístico por tramos** (`y = y0 + v0·τ − ½gτ²`, con τ desde `song_time`). El salto completo es idéntico a la parábola anterior. Soltar mientras sube multiplica la velocidad por `jump_cut_factor` (0,7): el toque corto sube ~0,9 (pasa barrera baja y hueco corto) y el completo 1,8 (plataformas y abismos).
- **Táctil:** toque = salto corto; deslizar arriba y mantener = salto alto. No se salta al apoyar el dedo porque todo swipe empieza con un toque.
- **Suelo por consulta.** El jugador pregunta `ground_height_at(x, song_time)` al spawner mediante un `Callable` que cablea `GameManager` (sin desfase de un frame, a diferencia de una señal). Hueco o fuera de pista = vacío; cima de plataforma = suelo. Caer más de `fall_death_depth` = derrota por caída.
- **Huecos como panel negro** con borde rojo a ras de pista, en vez de recortar la malla del piso: un draw call y sin geometría nueva.
- **Plataformas:** su frente llega al cubo en el beat de la fila (cima del salto). Entrar de lado o de frente sin saltar es choque (misma AABB de siempre, con un épsilon para estar parado encima).
- **Rampa obligatoria:** fila de muros con una rampa en un carril alcanzable; lanza un súper salto de 2 beats que sobrevuela una línea de muros 1 beat después. Es una sola fila con `tail` = vuelo, para no romper la separación mínima entre filas.
- **Muro móvil:** baila entre dos carriles cada beat y queda fijo 1 beat antes de llegar. Para el camino cuenta como muro en su carril final, así la garantía no cambia.
- **Tramos sin riel** (elección del dueño: solo en tramos señalizados): se deciden por compás, independientes de las filas. Se ocultan los rieles y aparecen marcas naranjas; el borde solo "mata" 0,6 beats hacia dentro del tramo, para que lo que se ve mande.
- **5 carriles.** Con más de 3 carriles cada fila bloquea carriles extra al azar para mantener la presión. Cámara más alta y atrás para que entren.
- **Niveles fijos** (`LevelCatalog`): cinco niveles con semilla y dificultad establecidas (variantes de Difícil que aprietan una mecánica) y meta en compases. Siguen pasando por el generador, así conservan la garantía de camino; el piloto automático los juega en los tests.
- **Gemas** sobre un carril realmente transitable de la fila; comparten pool con los obstáculos. Se cuentan aparte de la distancia.
- **UI Y2K por código:** `RetroWindow` (ventana Win98 neón), `SegmentDisplay` (dígitos de 7 segmentos, sin fuente) y `RetroGif` (animaciones a 10 fps). Godot no reproduce .gif: `RetroGif` carga `assets/sprites/<nombre>.png` (tira horizontal de cuadros cuadrados) si existe — nombres: `hud_gif`, `menu_gif_1..3`. Fuente: `assets/fonts/pixel.ttf` si existe; si no, monoespaciada del sistema sin antialias.
- **SFX sintetizados** (`SfxPlayer`) a `AudioStreamWAV` al arrancar, por un bus `SFX` creado en código (no hay `default_bus_layout.tres`). Volumen propio en opciones.
- **Pistas .ogg (cambio de regla, pedido por el dueño):** `TrackLibrary` lee `assets/audio/music/*_<BPM>bpm.ogg`; la pista se elige con la semilla musical (misma para todos ese día) y su BPM manda sobre el nivel. Sin pistas, vuelve la música procedural. El reloj usa `get_playback_position()` acumulando vueltas del loop. Requisito: BPM exacto, empezar en el primer beat y durar compases enteros.
- **Las tres pistas incluidas son originales**, compuestas con `tools/music/compose.py` (síntesis pura, sin samples): darkwave/EBM frío *en el estilo* de TR/ST, sin usar material suyo (tiene derechos). Regenerar: `python3 tools/music/compose.py <dir>` y convertir con `ffmpeg -c:a libvorbis -q:a 5`.
- **Pistas CC0 de OpenGameArt añadidas** (Darkness Road y su remake, 165 BPM, de MintoDog; Glutton, 120 BPM, de Kistol). Créditos en `assets/audio/music/CREDITS.md`. El BPM se comprobó con un detector de tempo y la duración da compases exactos. Cada nivel fijo tiene su pista (`TrackLibrary.assign`).
- **Fondos variados** (`SkyPresets`): 5 variantes del shader del cielo (paleta, sol/eclipse/sin astro, aurora, densidad de estrellas) elegidas por semilla; los niveles fijos tienen la suya.
- **Cuentas de Google: no se implementó OAuth.** Publicar no lo requiere. Logros/ranking/guardado en la nube van con Google Play Games Services (plugin Android + configuración en Play Console), que es trabajo del hito 7 y necesita aprobar un plugin.
