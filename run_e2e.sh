#!/usr/bin/env bash
# Runs the whole E2E flow with one command:
# database -> migrations -> seed data -> backend -> Flutter integration tests.
#
# Usage: ./run_e2e.sh [flutter device, default: linux]
#   E2E_PORT=8010 ./run_e2e.sh   # when another service already uses :8000
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${1:-linux}"
PORT="${E2E_PORT:-8000}"
# The Android emulator reaches the host through 10.0.2.2.
case "$DEVICE" in
  emulator*|android*) API_HOST="10.0.2.2" ;;
  *) API_HOST="127.0.0.1" ;;
esac
BACKEND_PID=""

cleanup() {
  if [ -n "$BACKEND_PID" ]; then
    kill "$BACKEND_PID" 2>/dev/null || true
    echo "Backend stopped."
  fi
}
trap cleanup EXIT

echo "1/5 Starting database..."
docker start unisport-postgres >/dev/null
until docker exec unisport-postgres pg_isready -U unisport >/dev/null 2>&1; do
  sleep 1
done

cd "$ROOT/backend"
# shellcheck disable=SC1091
source .venv/bin/activate

echo "2/5 Applying migrations..."
alembic upgrade head >/dev/null 2>&1

echo "3/5 Loading seed data (reset to a known state)..."
python seed.py --reset

echo "4/5 Starting backend..."
if curl -s -o /dev/null "http://127.0.0.1:$PORT/docs"; then
  # Reuse it only if it really is UniSport: another project's API on this
  # port would answer every request with "Not Found" and fail the whole suite.
  if curl -s "http://127.0.0.1:$PORT/openapi.json" | grep -q '"/api/partidos"'; then
    echo "UniSport backend already running on :$PORT, reusing it."
  else
    echo "Port $PORT is used by another service, not by UniSport."
    echo "Stop it, or run: E2E_PORT=8010 ./run_e2e.sh"
    exit 1
  fi
else
  uvicorn app.main:app --port "$PORT" >/tmp/unisport_backend.log 2>&1 &
  BACKEND_PID=$!
  until curl -s -o /dev/null "http://127.0.0.1:$PORT/docs"; do
    kill -0 "$BACKEND_PID" 2>/dev/null || {
      echo "Backend failed to start. See /tmp/unisport_backend.log"
      exit 1
    }
    sleep 1
  done
fi

echo "5/5 Running E2E tests on device: $DEVICE"
cd "$ROOT/frontend_flutter"
# One process per file: launching two desktop apps back to back in a single
# `flutter test` run is flaky because the first window is still closing.
FAILED=0
for test_file in integration_test/*_test.dart; do
  echo "=== $(basename "$test_file")"
  flutter test "$test_file" -d "$DEVICE" \
    --dart-define=API_BASE_URL="http://$API_HOST:$PORT" || FAILED=1
  sleep 3
done
exit "$FAILED"
