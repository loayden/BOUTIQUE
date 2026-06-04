#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PID_PATH="$ROOT_DIR/.mongodb/run/mongod.pid"

if [ ! -f "$PID_PATH" ]; then
  echo "MongoDB PID file not found."
  exit 0
fi

PID="$(cat "$PID_PATH")"

if kill -0 "$PID" >/dev/null 2>&1; then
  kill "$PID"
  echo "MongoDB stopped."
else
  echo "MongoDB process was not running."
fi

rm -f "$PID_PATH"
