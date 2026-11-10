#!/usr/bin/env bash
# Runs every test suite and saves the result under docs/evidencias/tarea-6/,
# or under SUITE_OUT_DIR when it is set.
#
# Usage: ./run_suite.sh <label> [flutter device, default: linux]
#   ./run_suite.sh antes     # before a feature
#   ./run_suite.sh despues   # after it
#   SUITE_OUT_DIR=evidencias/tarea-8 ./run_suite.sh despues
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
LABEL="${1:?Usage: ./run_suite.sh <label> [device]}"
DEVICE="${2:-linux}"
OUT_DIR="${SUITE_OUT_DIR:-$ROOT/docs/evidencias/tarea-6}"
case "$OUT_DIR" in /*) ;; *) OUT_DIR="$ROOT/$OUT_DIR" ;; esac
mkdir -p "$OUT_DIR"

header() {
  echo "Suite: $LABEL"
  echo "Date:  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Commit: $(git -C "$ROOT" rev-parse --short HEAD)"
  echo "Device: $DEVICE"
  echo
}

header >"$OUT_DIR/suite-$LABEL-backend.txt"
header >"$OUT_DIR/suite-$LABEL-flutter.txt"

echo "== Backend (pytest) =="
(cd "$ROOT/backend" && source .venv/bin/activate && python -m pytest -q 2>&1 | tail -3) \
  | tee -a "$OUT_DIR/suite-$LABEL-backend.txt"

echo "== Flutter widget tests =="
(cd "$ROOT/frontend_flutter" && flutter test 2>&1 | tail -1) \
  | tee -a "$OUT_DIR/suite-$LABEL-flutter.txt"

echo "== E2E ($DEVICE) =="
"$ROOT/run_e2e.sh" "$DEVICE" 2>&1 \
  | grep -E "^===|^[0-9:]+ \+[0-9]+.*(All tests passed|Some tests failed)|\[E\]" \
  | tee -a "$OUT_DIR/suite-$LABEL-flutter.txt"
