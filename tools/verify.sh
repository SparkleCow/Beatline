#!/usr/bin/env bash
# Verificación completa en headless:
#   1) importa el proyecto (detecta errores de parseo y recursos rotos),
#   2) corre los tests,
#   3) ejecuta la escena principal unos frames (detecta errores en tiempo de ejecución).
# Sale con código != 0 si algo falla.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_SH="$ROOT/tools/godot.sh"
SMOKE_FRAMES="${SMOKE_FRAMES:-300}"
LOG_DIR="$(mktemp -d)"
STATUS=0

# Godot imprime "SCRIPT ERROR", "Parse Error", "ERROR:" y "WARNING:" según el caso.
ERROR_PATTERN='SCRIPT ERROR|Parse Error|ERROR:|Failed to load|Invalid call|Cannot'
WARN_PATTERN='WARNING:'

check_log() {
  local name="$1" file="$2"
  local errors warnings
  errors=$(grep -E "$ERROR_PATTERN" "$file" | grep -v -E '^\s*$' || true)
  warnings=$(grep -E "$WARN_PATTERN" "$file" || true)
  if [ -n "$warnings" ]; then
    echo "---- Advertencias en $name ----"; echo "$warnings"
  fi
  if [ -n "$errors" ]; then
    echo "---- ERRORES en $name ----"; echo "$errors"; STATUS=1
  fi
}

echo "==> 1/3 Importando proyecto"
"$GODOT_SH" --import >"$LOG_DIR/import.log" 2>&1 || STATUS=1
check_log "importación" "$LOG_DIR/import.log"

echo "==> 2/3 Tests"
if ! "$GODOT_SH" -s res://tests/run_tests.gd >"$LOG_DIR/tests.log" 2>&1; then STATUS=1; fi
grep -E '^\[(OK|FALLA|ERROR)\]|tests, ' "$LOG_DIR/tests.log"
check_log "tests" "$LOG_DIR/tests.log"

echo "==> 3/3 Smoke test de la escena principal ($SMOKE_FRAMES frames)"
"$GODOT_SH" --quit-after "$SMOKE_FRAMES" -- --seed=12345 >"$LOG_DIR/smoke.log" 2>&1 || STATUS=1
check_log "escena principal" "$LOG_DIR/smoke.log"

echo "Logs completos en: $LOG_DIR"
if [ "$STATUS" -eq 0 ]; then echo "VERIFICACIÓN OK"; else echo "VERIFICACIÓN FALLIDA"; fi
exit "$STATUS"
