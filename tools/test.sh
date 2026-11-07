#!/usr/bin/env bash
# Run all tests headless. Usage: tools/test.sh [filter]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Build the class cache (class_name lookups) before running.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
args=()
if [[ $# -gt 0 ]]; then args=(-- "--filter=$1"); fi
"$GODOT" --headless --path . -s res://tests/run_tests.gd "${args[@]+"${args[@]}"}"
