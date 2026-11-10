# Roadmap

## Hito 1 — Prototipo gris ✅ (en curso de prueba)
Objetivo: comprobar si es divertido. Cubos grises y batería simple.
- [x] Semilla diaria determinista (UTC), forzable para depurar.
- [x] Reloj rítmico basado en el audio mezclado, con compensación de latencia.
- [x] Batería procedural mínima con `AudioStreamGenerator`.
- [x] Pista infinita de 3 carriles con segmentos reciclados.
- [x] Obstáculos anclados a beats, camino garantizado, tiempo mínimo de reacción.
- [x] Cambio de carril (swipe/flechas) y salto (toque/espacio).
- [x] Colisión, muerte, reinicio < 1 s, puntaje por distancia.
- [x] Overlay debug: BPM, beat, semilla, FPS.
- [ ] **Probar en un Android de gama baja real** y ajustar `GameConfig` / `DifficultyConfig` según la sensación.

## Hito 2 — Música procedural completa
Bajo y melodía (pentatónica menor / menor natural), progresiones, secciones (intro, build, drop), variación por compás. Render por adelantado en hilo para no tocar el frame. Obstáculos que siguen acentos de la música (no solo el pulso).

## Hito 3 — Estética neón y game feel
Glow, paleta neón sobre fondo oscuro, partículas, pulso de la pista con el bajo, cámara con *shake* sutil, vibración háptica, transiciones. Shaders simples y baratos.

## Hito 4 — Nivel diario, rachas y tarjeta para compartir
Pantalla de inicio con el nivel del día, mejor puntaje persistente, rachas de días jugados, tarjeta-imagen para compartir resultado (estilo "Wordle").

## Hito 5 — Modo infinito
Semilla aleatoria, dificultad creciente sin límite, récord propio.

## Hito 6 — Anuncios (AdMob) y analítica
Rewarded para revivir, intersticial como máximo cada 3–4 muertes, compra única para quitar anuncios. Eventos de analítica básicos (inicio, muerte, distancia, retención).

## Hito 7 — Lanzamiento en Android y web
Presets de exportación, iconos, ficha de tienda, pruebas en dispositivos, build web (Compatibility), luego iOS.
