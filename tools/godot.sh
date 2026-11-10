#!/usr/bin/env bash
# Ejecuta Godot SIEMPRE en modo headless sobre este proyecto.
# Busca el ejecutable en este orden: $GODOT, `godot`/`godot4` en PATH,
# y la ruta de instalación documentada en CLAUDE.md (Windows).
set -euo pipefail

GODOT_VERSION="4.7.2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${GODOT:-}"

if [ -z "$BIN" ]; then
  for c in godot godot4; do
    if command -v "$c" >/dev/null 2>&1; then BIN="$(command -v "$c")"; break; fi
  done
fi
if [ -z "$BIN" ]; then
  CANDIDATE="$HOME/Tools/godot/Godot_v${GODOT_VERSION}-stable_win64_console.exe"
  if [ -x "$CANDIDATE" ]; then BIN="$CANDIDATE"; fi
fi
if [ -z "$BIN" ]; then
  echo "No se encontró Godot ${GODOT_VERSION}. Define GODOT=/ruta/al/ejecutable o agrégalo al PATH." >&2
  exit 127
fi

exec "$BIN" --headless --path "$ROOT" "$@"
