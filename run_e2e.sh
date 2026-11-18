#!/usr/bin/env bash
# Ejecuta todo el flujo E2E con un solo comando:
# base de datos -> migraciones -> datos seed -> backend -> pruebas de integración de Flutter.
#
# Uso: ./run_e2e.sh [dispositivo de flutter, por defecto: linux]
#   E2E_PORT=8010 ./run_e2e.sh   # cuando otro servicio ya usa el puerto :8000
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${1:-linux}"
PORT="${E2E_PORT:-8000}"
# El emulador de Android accede a la máquina anfitriona a través de 10.0.2.2.
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
  # Se reutiliza solo si de verdad es UniSport: la API de otro proyecto en este
  # puerto respondería "Not Found" a todo y haría fallar toda la suite.
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
# Un proceso por archivo: lanzar dos apps de escritorio seguidas en una misma
# ejecución de `flutter test` es inestable porque la primera ventana aún se está cerrando.
FAILED=0
for test_file in integration_test/*_test.dart; do
  echo "=== $(basename "$test_file")"
  flutter test "$test_file" -d "$DEVICE" \
    --dart-define=API_BASE_URL="http://$API_HOST:$PORT" || FAILED=1
  sleep 3
done
exit "$FAILED"
