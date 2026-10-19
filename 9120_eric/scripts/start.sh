#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$TASK_ROOT"
bash scripts/database.sh
exec .venv/bin/python app.py
