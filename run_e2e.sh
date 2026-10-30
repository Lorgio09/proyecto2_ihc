#!/usr/bin/env bash
# Runs the whole E2E flow with one command:
# database -> migrations -> seed data -> backend -> Flutter integration tests.
#
# Usage: ./run_e2e.sh [flutter device, default: linux]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${1:-linux}"
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

echo "3/5 Loading seed data..."
python seed.py

echo "4/5 Starting backend..."
if curl -s -o /dev/null http://127.0.0.1:8000/docs; then
  echo "Backend already running on :8000, reusing it."
else
  uvicorn app.main:app --port 8000 >/tmp/unisport_backend.log 2>&1 &
  BACKEND_PID=$!
  until curl -s -o /dev/null http://127.0.0.1:8000/docs; do
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
  flutter test "$test_file" -d "$DEVICE" || FAILED=1
  sleep 3
done
exit "$FAILED"
