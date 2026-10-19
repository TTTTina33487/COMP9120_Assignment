#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$TASK_ROOT/instance" "$PGHOST"
chmod 700 "$PGHOST"
if [[ ! -f "$PGDATA/PG_VERSION" ]]; then
  "$PG_BIN/initdb" -D "$PGDATA" -A peer --auth-host=reject --encoding=UTF8 --locale=C.UTF-8
fi
if ! "$PG_BIN/pg_ctl" -D "$PGDATA" status > /dev/null 2>&1; then
  "$PG_BIN/pg_ctl" -D "$PGDATA" -l "$TASK_ROOT/instance/postgres.log" -o "-k $PGHOST -p $PGPORT -c listen_addresses='' -c timezone=UTC" -w start
fi
"$PG_BIN/pg_isready" -h "$PGHOST" -p "$PGPORT"
cd "$TASK_ROOT"
.venv/bin/python scripts/prepare_database.py
