#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
MONGO_DIR="$ROOT_DIR/.mongodb"
DATA_DIR="$MONGO_DIR/data"
LOG_DIR="$MONGO_DIR/log"
RUN_DIR="$MONGO_DIR/run"
LOG_PATH="$LOG_DIR/mongod.log"
PID_PATH="$RUN_DIR/mongod.pid"
PORT="${AURELIEN_MONGODB_PORT:-27017}"

mkdir -p "$DATA_DIR" "$LOG_DIR" "$RUN_DIR"

if mongosh --quiet "mongodb://127.0.0.1:${PORT}/admin" --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
  echo "MongoDB already running on 127.0.0.1:${PORT}"
  exit 0
fi

mongod \
  --dbpath "$DATA_DIR" \
  --logpath "$LOG_PATH" \
  --pidfilepath "$PID_PATH" \
  --fork \
  --bind_ip 127.0.0.1 \
  --port "$PORT"

echo "MongoDB started on 127.0.0.1:${PORT}"
