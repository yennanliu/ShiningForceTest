#!/usr/bin/env bash
# Run tests headless.
#   tools/test.sh                 all tests
#   tools/test.sh pathfinder      tests whose id contains "pathfinder"
#   tools/test.sh --dir=e2e       only tests/e2e (also: core, view)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Build the class cache (class_name lookups) before running.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
args=()
for a in "$@"; do
  if [[ "$a" == --* ]]; then args+=("$a"); else args+=("--filter=$a"); fi
done
if [[ ${#args[@]} -gt 0 ]]; then
  "$GODOT" --headless --path . -s res://tests/run_tests.gd -- "${args[@]}"
else
  "$GODOT" --headless --path . -s res://tests/run_tests.gd
fi
