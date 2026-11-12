---
description: Revisa el diff, verifica el proyecto y hace un commit con mensaje convencional
argument-hint: [pista opcional para el mensaje]
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git add *) Bash(git commit *) Bash(git branch *) Bash(./tools/verify.sh *) Read Grep Glob
---

Crea un checkpoint del trabajo actual. Pista del usuario para el mensaje (puede estar vacía): $ARGUMENTS

1. Ejecuta `git branch --show-current`. Si estás en `main`, detente y pide confirmación: se trabaja en `dev`.
2. Revisa `git status` y `git diff` (incluye archivos nuevos). Busca y reporta:
   - archivos que no deberían commitearse (`.godot/`, builds, `.env`, `secrets/`, binarios grandes fuera de LFS);
   - violaciones obvias de CLAUDE.md (tiempos con delta acumulado, números mágicos, código sin tipar).
3. Ejecuta `./tools/verify.sh`. Si falla, NO hagas commit: reporta el error y detente.
4. Si el diff mezcla cambios no relacionados, divídelo en varios commits pequeños (agrega archivos por grupo).
5. Escribe cada mensaje en formato Conventional Commits, en español, en imperativo:
   `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`, `perf:`. Primera línea ≤ 72 caracteres; cuerpo opcional explicando el porqué.
6. Haz el commit. **Nunca** hagas `git push`.
7. Muestra `git log --oneline -5` al final.
