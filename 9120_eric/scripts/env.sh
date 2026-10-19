#!/usr/bin/env bash
# Source from the repository root or any other working directory.
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PG_BIN="${PG_BIN:-/workspace/.tools/postgres/usr/lib/postgresql/17/bin}"
export PGDATA="${PGDATA:-$TASK_ROOT/instance/pgdata}"
export PGHOST="${PGHOST:-$TASK_ROOT/instance/pgsocket}"
export PGPORT="${PGPORT:-55432}"
export DATABASE_URL="${DATABASE_URL:-postgresql:///remote_education_db?host=$PGHOST&port=$PGPORT}"
export DEMO_LOGIN="${DEMO_LOGIN:-1}"
