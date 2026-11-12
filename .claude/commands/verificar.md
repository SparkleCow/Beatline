---
description: Verifica el proyecto en headless (parseo, advertencias, tests y smoke test de la escena principal)
allowed-tools: Bash(./tools/verify.sh *) Bash(./tools/godot.sh *) Read Grep Glob
---

Verifica el proyecto Godot en modo headless y reporta el resultado.

1. Ejecuta `./tools/verify.sh`. Hace tres pasos: importar el proyecto (errores de parseo y recursos rotos), correr `tests/run_tests.gd` y ejecutar la escena principal 300 frames con `--seed=12345`.
2. Si falla porque no encuentra Godot, explica cómo definir `GODOT` (ver CLAUDE.md, sección Stack) y detente.
3. Reporta en este formato:
   - **Errores de parseo / ejecución:** lista con archivo:línea (o "ninguno").
   - **Advertencias:** lista agrupada por tipo (o "ninguna"). Ignora solo advertencias del propio motor ajenas al proyecto, indicándolo.
   - **Tests:** N pasados / M fallidos, con el mensaje de cada falla.
   - **Veredicto:** OK o FALLIDO.
4. Si algo falla, abre los archivos implicados y propone la causa probable, pero NO edites nada salvo que te lo pidan.
