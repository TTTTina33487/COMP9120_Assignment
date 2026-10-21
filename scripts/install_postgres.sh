#!/usr/bin/env bash
# Non-root Debian 13 installation; apt verifies signed package metadata/hashes.
set -euo pipefail
task_tools=/workspace/.tools
if [[ -x "$task_tools/postgres/usr/lib/postgresql/17/bin/pg_ctl" ]]; then
  "$task_tools/postgres/usr/lib/postgresql/17/bin/postgres" --version
  exit 0
fi
mkdir -p "$task_tools/apt/lists/partial" "$task_tools/apt/cache/archives/partial" "$task_tools/debs"
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian trixie main' > "$task_tools/apt/sources.list"
task_apt=(-o Dir::Etc::parts=- -o "Dir::Etc::sourcelist=$task_tools/apt/sources.list" -o Dir::Etc::sourceparts=- -o "Dir::State::lists=$task_tools/apt/lists" -o "Dir::Cache=$task_tools/apt/cache" -o Debug::NoLocking=1 -o Acquire::Retries=0)
apt-get "${task_apt[@]}" update
cd "$task_tools/debs"
apt-get "${task_apt[@]}" download postgresql-17 postgresql-client-17 libpq5 libllvm19 libldap2
mkdir -p "$task_tools/postgres"
for task_deb in ./*.deb; do dpkg-deb -x "$task_deb" "$task_tools/postgres"; done
"$task_tools/postgres/usr/lib/postgresql/17/bin/postgres" --version
